import Foundation
import SwiftUI
import Combine
import UIKit
import AVFoundation
import MWDATCore
import MWDATCamera

@MainActor
class StreamManager: ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var status = "Ready to Stream"
    @Published var isStreaming = false

    private var streamSession: StreamSession?
    private var token: AnyListenerToken?

    var rtmpManager: RTMPManager?

    private func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func startStreaming() async {
        status = "Checking permissions..."

        let currentStatus = try? await Wearables.shared.checkPermissionStatus(.camera)
        if currentStatus != .granted {
            status = "Requesting permission..."
            let requestResult = try? await Wearables.shared.requestPermission(.camera)
            if requestResult != .granted {
                status = "Permission denied. Check Meta AI app."
                return
            }
        }

        status = "Configuring Audio..."
        configureAudio()

        status = "Configuring session..."
        let selector = AutoDeviceSelector(wearables: Wearables.shared)

        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .high,
            frameRate: 24
        )

        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        self.streamSession = session

        token = session.videoFramePublisher.listen { [weak self] frame in
            if let image = frame.makeUIImage() {
                Task { @MainActor in
                    self?.currentFrame = image
                    self?.status = "Streaming Live"
                    self?.isStreaming = true
                }
            }

            let buffer = frame.sampleBuffer

            Task { @MainActor in
                self?.rtmpManager?.processVideoFrame(buffer)
            }
        }

        status = "Starting stream..."
        await session.start()
    }

    func stopStreaming() async {
        status = "Stopping..."
        await streamSession?.stop()
        await rtmpManager?.stopBroadcast()

        status = "Ready to Stream"
        isStreaming = false
        currentFrame = nil
    }
}
