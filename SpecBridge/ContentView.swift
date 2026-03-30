import SwiftUI
import MWDATCore

struct ContentView: View {
    @AppStorage("mediamtx_host") private var mediamtxHost: String = ""
    @AppStorage("mediamtx_stream_key") private var streamKey: String = ""

    @StateObject private var streamManager = StreamManager()
    @StateObject private var rtmpManager = RTMPManager()

    var body: some View {
        NavigationStack { // Spostata qui per coprire entrambe le condizioni
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
    
    // 1. Enum aggiornato con le piattaforme principali (no Meta, no MediaMTX)
    enum Platform: String, CaseIterable, Identifiable {
        case youtube = "YouTube"
        case twitch = "Twitch"
        case tiktok = "TikTok"
        case kick = "Kick"
        case xTwitter = "X (Twitter)"
        case custom = "Custom RTMP"
        
        var id: String { self.rawValue }
        
        // Host predefinito da autocompilare (se fisso per quella piattaforma)
        var defaultHost: String {
            switch self {
            case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
            case .twitch: return "rtmp://live.twitch.tv/app/"
            case .tiktok, .kick, .xTwitter, .custom: return "" // Queste richiedono l'URL specifico fornito dal sito
            }
        }
        
        // 2. Placeholder dinamico per il Server URL
        var hostPlaceholder: String {
            switch self {
            case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
            case .twitch: return "rtmp://live.twitch.tv/app/"
            case .tiktok: return "Es. rtmp://push-rtmp-l11...tiktokcdn.com"
            case .kick: return "Es. rtmps://fa723fc1b171.global-contribute..."
            case .xTwitter: return "Es. rtmps://default.video.x.com:443/app/"
            case .custom: return "Inserisci l'URL del server RTMP"
            }
        }
        
        // 3. Placeholder dinamico per la Stream Key
        var keyPlaceholder: String {
            switch self {
            case .youtube: return "Es. abcd-1234-efgh-5678"
            case .twitch: return "live_0000000_xxxxxxxxxxxx"
            case .tiktok: return "Inserisci la stream key di TikTok"
            case .kick: return "stream_xxxxxxxxxxxx"
            case .xTwitter: return "xxxxxxxxxxxx"
            case .custom: return "Inserisci la stream key"
            }
        }
        
        var icon: String {
            switch self {
            case .youtube: return "play.rectangle.fill"
            case .twitch: return "play.tv.fill"
            case .tiktok: return "music.note"
            case .kick: return "k.circle.fill" // Nessun SF Symbol nativo per Kick, usiamo la K
            case .xTwitter: return "xmark"
            case .custom: return "link"
            }
        }
    }
    
    @State private var selectedPlatform: Platform = .youtube

    var body: some View {
        VStack(spacing: 25) {
            
            // Sezione Scelta Piattaforma
            VStack(alignment: .leading, spacing: 10) {
                Text("Stream Destination")
                    .font(.headline)
                    .padding(.horizontal)
                
                Picker("Choose Platform", selection: $selectedPlatform) {
                    ForEach(Platform.allCases) { platform in
                        HStack {
                            Text(platform.rawValue)
                            Image(systemName: platform.icon)
                        }.tag(platform)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .onChange(of: selectedPlatform) { newValue in
                    // Autocompila l'host se la piattaforma ne ha uno standard, altrimenti svuota
                    inputHost = newValue.defaultHost
                    // Svuotiamo sempre la chiave per sicurezza quando si cambia piattaforma
                    inputKey = ""
                }
            }

            // Input Campi di Testo con Placeholder Dinamici
            VStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Server URL (Host)")
                        .font(.caption).foregroundStyle(.secondary)
                    
                    // Usiamo hostPlaceholder basato sulla selezione
                    TextField(selectedPlatform.hostPlaceholder, text: $inputHost)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Stream Key")
                        .font(.caption).foregroundStyle(.secondary)
                    
                    // Usiamo keyPlaceholder basato sulla selezione
                    TextField(selectedPlatform.keyPlaceholder, text: $inputKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .padding(.horizontal)

            Divider().padding(.vertical, 10)

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
            .controlSize(.large)
            .disabled(inputHost.isEmpty || inputKey.isEmpty)
            
            Spacer()
        }
        .padding(.top)
        .navigationTitle("Setup")
        .onAppear {
            // Imposta l'host di default all'avvio se vuoto
            if inputHost.isEmpty {
                inputHost = selectedPlatform.defaultHost
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { /* Azioni impostazioni */ } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
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
            // ... (ZStack del video rimane uguale)
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

            // ... (VStack delle info rimane uguale)
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

            // Pulsante Go Live centralizzato
            Button(streamManager.isStreaming ? "Stop Streaming" : "Go Live") {
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
            .controlSize(.large) // Più facile da premere
            .tint(streamManager.isStreaming ? .red : .green)
        }
        .padding()
        .navigationTitle("Live") // Titolo per la vista streaming
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onLogout) { // Esegue la stessa funzione del vecchio tasto
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
