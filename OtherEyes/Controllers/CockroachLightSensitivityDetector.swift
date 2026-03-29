//
//  LightSensitivityDetector.swift
//  OtherEyes
//
//  Detects sudden brightness changes between frames for
//  Cockroach light-sensitivity flicker effect.
//

import CoreImage
import CoreImage.CIFilterBuiltins

final class LightSensitivityDetector: @unchecked Sendable {

    /// Current flicker intensity (0 = none, up to ~0.4 on sudden flash).
    /// Decays rapidly back to 0.
    private(set) var flickerIntensity: Float = 0

    private var previousBrightness: Float = 0
    private var isFirstFrame = true

    // Thresholds — only trigger on noticeable changes
    private let triggerThreshold: Float = 0.06   // minimum brightness delta to trigger
    private let maxFlicker: Float = 0.35          // cap the flicker intensity
    private let decayRate: Float = 0.85           // how fast flicker fades (per frame)

    /// Call once per frame with a downsampled CIImage.
    /// Uses CIAreaAverage to cheaply compute mean brightness.
    func update(image: CIImage, context: CIContext) {
        // Sample brightness from a small centre region (cheap)
        let extent = image.extent
        let sampleRect = CGRect(
            x: extent.midX - 50, y: extent.midY - 50,
            width: 100, height: 100
        ).intersection(extent)

        guard let avg = CIFilter(name: "CIAreaAverage") else {
            decayFlicker()
            return
        }
        avg.setValue(image, forKey: kCIInputImageKey)
        avg.setValue(CIVector(cgRect: sampleRect), forKey: "inputExtent")

        guard let output = avg.outputImage,
              let cgImg = context.createCGImage(output, from: CGRect(x: 0, y: 0, width: 1, height: 1)) else {
            decayFlicker()
            return
        }

        // Read the single-pixel average
        let data = cgImg.dataProvider?.data
        let ptr = CFDataGetBytePtr(data)
        let r = Float(ptr?[0] ?? 0) / 255.0
        let g = Float(ptr?[1] ?? 0) / 255.0
        let b = Float(ptr?[2] ?? 0) / 255.0
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b

        if isFirstFrame {
            previousBrightness = brightness
            isFirstFrame = false
            return
        }

        let delta = abs(brightness - previousBrightness)

        if delta > triggerThreshold {
            // Sudden brightness change → spike the flicker
            flickerIntensity = min(delta * 3.0, maxFlicker)
        } else {
            decayFlicker()
        }

        previousBrightness = brightness
    }

    private func decayFlicker() {
        flickerIntensity *= decayRate
        if flickerIntensity < 0.01 { flickerIntensity = 0 }
    }

    func reset() {
        flickerIntensity = 0
        previousBrightness = 0
        isFirstFrame = true
    }
}
