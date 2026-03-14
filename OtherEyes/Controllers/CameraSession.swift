import Foundation
import AVFoundation
import SwiftUI
import Combine

/// Lightweight camera session manager
@MainActor
final class CameraSession: NSObject, ObservableObject {
    // Explicit objectWillChange publisher to satisfy ObservableObject conformance
    let objectWillChange = PassthroughSubject<Void, Never>()

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    override init() {
        super.init()
        configure()
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()

        sessionQueue.async {
            self.session.startRunning()
        }
    }

    deinit {
        session.stopRunning()
    }
}
