//
//  VisionTransitionManager.swift
//  OtherEyes
//

import Foundation
import QuartzCore

/// Drives smooth crossfade transitions between animal vision filters.
///
/// When `beginTransition(from:to:)` is called, `progress` interpolates
/// from 0 → 1 over `duration` seconds using easeInOut timing.
/// The camera pipeline reads `progress` each frame to blend filters.
final class VisionTransitionManager: @unchecked Sendable {

    // MARK: - Public state

    /// 0 = fully previous animal, 1 = fully new animal.
    private(set) var progress: Float = 1.0

    /// `true` while a transition is animating.
    private(set) var isTransitioning: Bool = false

    /// The animal we're transitioning *from* (previous selection).
    private(set) var previousAnimal: Animal?

    // MARK: - Configuration

    /// Total transition duration in seconds.
    var duration: TimeInterval = 0.45

    // MARK: - Internals

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0

    // MARK: - Transition control

    /// Start blending from `oldAnimal` to `newAnimal`.
    func beginTransition(from oldAnimal: Animal, to newAnimal: Animal) {
        // If already transitioning, snap to end of the old one first.
        if isTransitioning {
            finishTransition()
        }

        previousAnimal = oldAnimal
        progress = 0.0
        isTransitioning = true
        startTime = CACurrentMediaTime()

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Immediately complete the current transition.
    func finishTransition() {
        displayLink?.invalidate()
        displayLink = nil
        progress = 1.0
        isTransitioning = false
        previousAnimal = nil
    }

    // MARK: - Display link callback

    @objc private func tick(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - startTime
        let linear = Float(min(elapsed / duration, 1.0))

        // EaseInOut curve: 3t² − 2t³  (Hermite interpolation)
        progress = linear * linear * (3.0 - 2.0 * linear)

        if linear >= 1.0 {
            finishTransition()
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}
