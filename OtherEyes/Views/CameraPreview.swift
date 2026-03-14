import SwiftUI
import UIKit
import AVFoundation

/// A simple UIViewRepresentable that hosts an AVCaptureVideoPreviewLayer
struct CameraPreview: UIViewRepresentable {
    class VideoView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    @ObservedObject var camera: CameraSession

    func makeUIView(context: Context) -> VideoView {
        let view = VideoView()
        view.backgroundColor = .clear
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = camera.session
        return view
    }

    func updateUIView(_ uiView: VideoView, context: Context) {
        uiView.previewLayer.session = camera.session
    }
}
