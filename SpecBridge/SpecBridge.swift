import Foundation
import Combine
import AVFoundation
import HaishinKit
import RTMPHaishinKit
import VideoToolbox

@MainActor
class RTMPManager: ObservableObject {
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!

    @Published var isBroadcasting = false
    @Published var connectionStatus = "Disconnected"

    init() {
        rtmpStream = RTMPStream(connection: rtmpConnection)
    }

    func startBroadcast(host: String, streamKey: String) async {
        let rtmpURL = "rtmp://\(host):1935/live"
        connectionStatus = "Connecting..."

        do {
            /*let videoSettings = VideoCodecSettings(
                videoSize: .init(width: 720, height: 1280),
                bitRate: 2500 * 1000,
                profileLevel: kVTProfileLevel_H264_High_3_1 as String,
                scalingMode: .trim,
                maxKeyFrameIntervalDuration: 2,
                expectedFrameRate: 24
            )*/
            // Main spec settings for 2160x2880 @ 30fps with good quality (Test)
            let videoSettings = VideoCodecSettings(
                videoSize: .init(width: 2208, height: 2944), 
                bitRate: 17000 * 1000,                       
                profileLevel: kVTProfileLevel_H264_High_5_2 as String, 
                scalingMode: .trim,
                maxKeyFrameIntervalDuration: 2,
                expectedFrameRate: 30                        
            )
            try await rtmpStream.setVideoSettings(videoSettings)
            try await rtmpConnection.connect(rtmpURL)
            try await rtmpStream.publish(streamKey)

            connectionStatus = "Live"
            isBroadcasting = true
        } catch {
            connectionStatus = "Failed: \(error.localizedDescription)"
            isBroadcasting = false
        }
    }

    func stopBroadcast() async {
        do {
            try await rtmpConnection.close()
        } catch {
            print("Error closing stream: \(error)")
        }
        isBroadcasting = false
        connectionStatus = "Disconnected"
    }

    func processVideoFrame(_ buffer: CMSampleBuffer) {
        Task {
            try? await rtmpStream.append(buffer)
        }
    }
}
