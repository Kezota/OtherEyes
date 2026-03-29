//
//  ParallaxManager.swift
//  OtherEyes
//
//  Reads device gyroscope via CoreMotion and exposes X/Y
//  offset values for Ant parallax effect.
//  tilting the device shifts the camera view subtly.
//

import CoreMotion
import Foundation

final class ParallaxManager: @unchecked Sendable {

    struct ParallaxOffset {
        var x: CGFloat = 0   // horizontal shift (pixels)
        var y: CGFloat = 0   // vertical shift (pixels)
    }

    private(set) var currentOffset = ParallaxOffset()

    private let motionManager = CMMotionManager()

    // Maximum pixel shift — kept small to avoid dizziness
    private let maxShift: CGFloat = 12.0

    func start() {
        guard motionManager.isGyroAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }

            // Map pitch/roll to pixel offsets
            // pitch = forward/back tilt, roll = left/right tilt
            let x = CGFloat(attitude.roll)  * self.maxShift   // ±12 px
            let y = CGFloat(attitude.pitch) * self.maxShift   // ±12 px

            self.currentOffset = ParallaxOffset(
                x: x.clamped(to: -self.maxShift...self.maxShift),
                y: y.clamped(to: -self.maxShift...self.maxShift)
            )
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        currentOffset = ParallaxOffset()
    }
}

// MARK: - CGFloat clamping utility
private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
