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
        // 1. Pulizia URL: Se l'utente incolla già "rtmp://", non lo duplichiamo
        let rtmpURL: String
        if host.lowercased().hasPrefix("rtmp") {
            rtmpURL = host
        } else {
            rtmpURL = "rtmp://\(host)/live" // Fallback per MediaMTX o simili
        }
        
        connectionStatus = "Connecting..."

        do {
            // 2. Configurazione dinamica del Bitrate
            // Se è Twitch, forziamo un limite di sicurezza (6Mbps)
            // Se è YouTube o Custom, possiamo osare di più se la connessione regge
            let isTwitch = host.contains("twitch.tv")
            let targetBitrate = isTwitch ? 6000 * 1000 : 12000 * 1000
            
            // Nota: 2208x2944 è molto pesante. Per stabilità suggerisco 1080x1440
            // ma mantengo i tuoi valori adattandoli
            let videoSettings = VideoCodecSettings(
                videoSize: .init(width: 2208, height: 2944),
                bitRate: targetBitrate,
                profileLevel: kVTProfileLevel_H264_High_5_2 as String,
                scalingMode: .trim,
                maxKeyFrameIntervalDuration: 2, // Fondamentale per piattaforme social
                expectedFrameRate: 30
            )

            try await rtmpStream.setVideoSettings(videoSettings)
            
            // 3. Connessione e Pubblicazione
            try await rtmpConnection.connect(rtmpURL)
            
            // Alcune piattaforme richiedono lo streamKey nel publish
            try await rtmpStream.publish(streamKey)

            connectionStatus = "Live"
            isBroadcasting = true
        } catch {
            connectionStatus = "Error: \(error.localizedDescription)"
            isBroadcasting = false
            print("RTMP Error: \(error)")
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
