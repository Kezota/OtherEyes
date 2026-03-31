//
//  AmbientEffectEngine.swift
//  OtherEyes
//

import Foundation
import QuartzCore
import CoreImage

/// Produces per-animal continuous ambient effect parameters each frame.
///
/// All effects are sinusoidal, slow (2–4 s cycles), and barely noticeable.
/// The engine outputs a lightweight `AmbientParams` struct that the
/// filter processor applies without adding extra CIFilter passes.
final class AmbientEffectEngine: @unchecked Sendable {

    // MARK: - Output parameters

    struct AmbientParams {
        /// Tiny X/Y translation for jitter effects (Fly)
        var translationX: CGFloat = 0
        var translationY: CGFloat = 0

        /// Distortion center offset for wave effects (Fish)
        var distortionOffsetX: CGFloat = 0
        var distortionOffsetY: CGFloat = 0

        /// Exposure delta for flicker effects (Cockroach)
        var exposureDelta: Float = 0

        /// Scale multiplier for breathing effects (Bird)
        var scaleFactor: CGFloat = 1.0

        /// Hue rotation delta in radians (Mantis Shrimp)
        var hueShift: Float = 0

        /// Eagle: slow zoom breathing (subtle focus pulse)
        var eagleBreathScale: CGFloat = 1.0

        /// Crocodile: slow vertical drift
        var crocDriftY: CGFloat = 0

        /// Crocodile: slow water distortion wave
        var crocWaveOffset: CGFloat = 0
    }

    /// Current frame's ambient parameters. Read from the render thread.
    private(set) var currentParams = AmbientParams()

    // MARK: - Internals

    private var displayLink: CADisplayLink?
    private let startTime: CFTimeInterval = CACurrentMediaTime()

    // MARK: - Lifecycle

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        currentParams = AmbientParams()
    }

    // MARK: - Per-frame update

    @objc private func tick(_ link: CADisplayLink) {
        let t = CACurrentMediaTime() - startTime

        var p = AmbientParams()

        // Fly: micro jitter — very small, fast-ish
        let jitterCycle = 1.8
        p.translationX = CGFloat(sin(t * 2 * .pi / jitterCycle) * 1.5)
        p.translationY = CGFloat(cos(t * 2 * .pi / jitterCycle * 1.3) * 1.0)

        // Fish: gentle wave — slow oscillation of distortion center
        let waveCycle = 3.0
        p.distortionOffsetX = CGFloat(sin(t * 2 * .pi / waveCycle) * 8.0)
        p.distortionOffsetY = CGFloat(cos(t * 2 * .pi / waveCycle * 0.7) * 5.0)

        // Cockroach: dim flicker — very subtle exposure oscillation
        let flickerCycle = 2.5
        p.exposureDelta = Float(sin(t * 2 * .pi / flickerCycle) * 0.03)

        // Bird: zoom breathing — barely perceptible scale oscillation
        let breathCycle = 3.5
        p.scaleFactor = 1.0 + CGFloat(sin(t * 2 * .pi / breathCycle) * 0.006)

        // Mantis Shrimp: slow hue drift — ±5° (≈ ±0.087 radians)
        let hueCycle = 4.0
        p.hueShift = Float(sin(t * 2 * .pi / hueCycle) * 0.087)

        // Eagle: slow zoom breathing — ±0.7% scale over 4s
        let eagleCycle = 4.0
        p.eagleBreathScale = 1.0 + CGFloat(sin(t * 2 * .pi / eagleCycle) * 0.007)

        // Crocodile: slow drift and water wave
        let crocCycle = 4.5
        p.crocDriftY = CGFloat(sin(t * 2 * .pi / crocCycle) * 3.0)
        p.crocWaveOffset = CGFloat(sin(t * 2 * .pi / (crocCycle * 0.8)) * 4.0)

        currentParams = p
    }

    deinit {
        displayLink?.invalidate()
    }
}
