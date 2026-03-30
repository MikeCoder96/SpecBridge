import SwiftUI
import MWDATCore

struct ContentView: View {
    @AppStorage("mediamtx_host") private var mediamtxHost: String = ""
    @AppStorage("mediamtx_stream_key") private var streamKey: String = ""

    @StateObject private var streamManager = StreamManager()
    @StateObject private var rtmpManager = RTMPManager()

    var body: some View {
        Group {
            if mediamtxHost.isEmpty || streamKey.isEmpty {
                SetupView(host: $mediamtxHost, streamKey: $streamKey)
            } else {
                StreamingView(
                    streamManager: streamManager,
                    rtmpManager: rtmpManager,
                    host: mediamtxHost,
                    streamKey: streamKey,
                    onLogout: {
                        mediamtxHost = ""
                        streamKey = ""
                    }
                )
            }
        }
        .onAppear {
            streamManager.rtmpManager = rtmpManager
        }
        .onOpenURL { url in
            Task { try? await Wearables.shared.handleUrl(url) }
        }
    }
}

struct SetupView: View {
    @Binding var host: String
    @Binding var streamKey: String

    @State private var inputHost = ""
    @State private var inputKey = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Setup")
                .font(.largeTitle).bold()

            TextField("MediaMTX host (e.g. 192.168.1.10)", text: $inputHost)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal)

            TextField("Title of the live stream", text: $inputKey)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal)

            Button("Connect to Meta Glasses") {
                try? Wearables.shared.startRegistration()
            }
            .buttonStyle(.bordered)

            Button("Save & Continue") {
                if !inputHost.isEmpty && !inputKey.isEmpty {
                    host = inputHost
                    streamKey = inputKey
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputHost.isEmpty || inputKey.isEmpty)
        }
        .padding()
    }
}

struct StreamingView: View {
    @ObservedObject var streamManager: StreamManager
    @ObservedObject var rtmpManager: RTMPManager
    var host: String
    var streamKey: String
    var onLogout: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Color.black
                if let videoImage = streamManager.currentFrame {
                    Image(uiImage: videoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text("Glasses Offline")
                        .foregroundStyle(.gray)
                }
            }
            .frame(height: 500)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 4) {
                Text("Glasses: \(streamManager.status)")
                    .font(.subheadline)
                Text("RTMP: \(rtmpManager.connectionStatus)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(rtmpManager.isBroadcasting ? .green : .red)
                Text("\(host)/\(streamKey)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button(streamManager.isStreaming ? "Stop" : "Go Live") {
                    Task {
                        if streamManager.isStreaming {
                            await streamManager.stopStreaming()
                        } else {
                            await streamManager.startStreaming()
                            await rtmpManager.startBroadcast(host: host, streamKey: streamKey)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(streamManager.isStreaming ? .red : .green)

                Button("Settings") {
                    onLogout()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
