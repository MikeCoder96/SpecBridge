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

    // RTMPManager.swift

    func startBroadcast(host: String, streamKey: String, settings: VideoQualitySettings) async {
        // 1. Costruisci l'URL (come abbiamo visto prima)
        let rtmpURL: String
        if host.lowercased().hasPrefix("rtmp") {
            rtmpURL = host
        } else {
            rtmpURL = "rtmp://\(host)/live"
        }
        
        connectionStatus = "Connecting..."

        do {
            // 2. Usa i valori che arrivano dall'oggetto 'settings'
            let videoSettings = VideoCodecSettings(
                videoSize: .init(width: settings.width, height: settings.height),
                bitRate: settings.bitrate, // Già moltiplicato per 1000 nel popup
                profileLevel: kVTProfileLevel_H264_High_5_2 as String,
                scalingMode: .trim,
                maxKeyFrameIntervalDuration: 2,
                expectedFrameRate: Float64(settings.frameRate)
            )

            try await rtmpStream.setVideoSettings(videoSettings)
            try await rtmpConnection.connect(rtmpURL)
            try await rtmpStream.publish(streamKey)

            connectionStatus = "Live"
            isBroadcasting = true
        } catch {
            connectionStatus = "Error: \(error.localizedDescription)"
            isBroadcasting = false
        }
    }
    
    func stopBroadcast() async {
        do {
            try await rtmpStream.close()
            try await rtmpConnection.close()
        } catch {
            print("Error closing stream: \(error)")
        }
        isBroadcasting = false
        connectionStatus = "Disconnected"
    }

    func processVideoFrame(_ buffer: CMSampleBuffer) {
        // Evitiamo di processare frame se non siamo in onda
        guard isBroadcasting else { return }
        
        Task {
            // HaishinKit 1.9.0+ usa append per i sample buffer
            try? await rtmpStream.append(buffer)
        }
    }
}
