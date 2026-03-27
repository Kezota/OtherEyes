//
//  CameraManager.swift
//  OtherEyes
//

import AVFoundation
import Combine
import CoreImage
import UIKit
import SwiftUI
import os

// Thread-safe box to share selectedAnimal across actor boundaries
fileprivate final class AtomicAnimal: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: Animal.dog)
    
    var value: Animal {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

// MARK: - Camera lens preference per animal
extension Animal {
    /// Animals that benefit from the real 0.5× ultra-wide camera.
    /// Eagle uses ultra-wide for wider FOV — focus comes from radial blur, not zoom.
    var prefersUltraWide: Bool {
        switch self {
        case .bird, .fish, .eagle: return true
        default:                   return false
        }
    }
}

@MainActor
class CameraManager: NSObject, ObservableObject {
    
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue  = DispatchQueue(label: "com.othereyes.camera.session")
    private let processingQueue = DispatchQueue(label: "com.othereyes.camera.processing")

    // Shared between main actor and background delegate — protected by AtomicAnimal
    nonisolated(unsafe) private let atomicAnimal = AtomicAnimal()

    nonisolated(unsafe) private let filterProcessor = AnimalFilterProcessor()
    nonisolated(unsafe) private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // ── Transition & Ambient engines ─────────────────────────────────────
    nonisolated(unsafe) let transitionManager = VisionTransitionManager()
    nonisolated(unsafe) let ambientEngine = AmbientEffectEngine()

    // ── Perception-based behavioral helpers ──────────────────────────────
    nonisolated(unsafe) let temporalBuffer = TemporalBuffer(capacity: 4)
    nonisolated(unsafe) let motionAnalyzer = MotionAnalyzer()
    nonisolated(unsafe) let parallaxManager = ParallaxManager()
    nonisolated(unsafe) let lightDetector = LightSensitivityDetector()

    // Retained strongly so AVFoundation delegate is never deallocated
    nonisolated(unsafe) private var delegateWrapper: CameraDelegateWrapper?

    // Track which lens is currently active so we only switch when needed
    nonisolated(unsafe) private var currentLensIsUltraWide: Bool = false

    @Published var filteredImage: UIImage?
    @Published var rawImage: UIImage?
    @Published var isAuthorized: Bool = false
    
    @Published var selectedAnimal: Animal = .dog {
        didSet {
            let oldAnimal = oldValue
            atomicAnimal.value = selectedAnimal

            // Start smooth crossfade transition
            if oldAnimal != selectedAnimal {
                transitionManager.beginTransition(from: oldAnimal, to: selectedAnimal)
            }

            // Switch camera lens if the animal requires a different one
            let needsUltraWide = selectedAnimal.prefersUltraWide
            if needsUltraWide != currentLensIsUltraWide {
                switchCameraLens(useUltraWide: needsUltraWide)
            }

            // 🐱 Cat night-vision: turn torch on at low intensity
            setTorch(on: selectedAnimal == .cat)
        }
    }
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession(useUltraWide: false)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupSession(useUltraWide: false) }
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    // MARK: - Initial session setup
    private func setupSession(useUltraWide: Bool) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            let device = self.bestCamera(ultraWide: useUltraWide)
            guard let device,
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.currentLensIsUltraWide = useUltraWide && (device.deviceType == .builtInUltraWideCamera)

            let wrapper = CameraDelegateWrapper(manager: self,
                                                filterProcessor: self.filterProcessor,
                                                ciContext: self.ciContext,
                                                atomicAnimal: self.atomicAnimal,
                                                transitionManager: self.transitionManager,
                                                ambientEngine: self.ambientEngine,
                                                temporalBuffer: self.temporalBuffer,
                                                motionAnalyzer: self.motionAnalyzer,
                                                parallaxManager: self.parallaxManager,
                                                lightDetector: self.lightDetector)
            self.delegateWrapper = wrapper
            self.videoOutput.setSampleBufferDelegate(wrapper, queue: self.processingQueue)
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            self.configureRotation()
            self.session.commitConfiguration()
        }
    }

    // MARK: - Hot-swap between standard and ultra-wide lenses
    private func switchCameraLens(useUltraWide: Bool) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let device = self.bestCamera(ultraWide: useUltraWide)
            guard let device, let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            self.session.beginConfiguration()
            // Remove existing inputs
            for input in self.session.inputs { self.session.removeInput(input) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentLensIsUltraWide = useUltraWide && (device.deviceType == .builtInUltraWideCamera)
            }
            self.configureRotation()
            self.session.commitConfiguration()
        }
    }

    // MARK: - Helpers
    /// Returns the best available camera. Falls back to wide-angle if ultra-wide isn't available.
    private func bestCamera(ultraWide: Bool) -> AVCaptureDevice? {
        if ultraWide,
           let uw = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            return uw
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func configureRotation() {
        if let connection = self.videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }

    func startSession() {
        ambientEngine.start()
        parallaxManager.start()
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        ambientEngine.stop()
        parallaxManager.stop()
        setTorch(on: false)  // always kill torch when leaving
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Torch (flashlight) control
    /// Turns the device torch on at low intensity (cat night-vision) or off.
    private func setTorch(on: Bool) {
        sessionQueue.async {
            guard let device = AVCaptureDevice.default(for: .video),
                  device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                if on {
                    // Low intensity so it's not blinding — simulates tapetum glow
                    try device.setTorchModeOn(level: 0.08)  // 0.0–1.0, 0.08 ≈ very faint glow
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                // Torch unavailable — silently ignore
            }
        }
    }
    
    // Called from the delegate wrapper on main thread
    func updateImages(raw: UIImage?, filtered: UIImage?) {
        if let raw      { self.rawImage      = raw }
        if let filtered { self.filteredImage = filtered }
    }
}

// MARK: - Delegate Wrapper (nonisolated, Sendable)
// Separating the delegate into its own object avoids the Swift 6
// actor-isolation conflict on captureOutput being called from a background thread.
final class CameraDelegateWrapper: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    
    private weak var manager: CameraManager?
    private let filterProcessor: AnimalFilterProcessor
    private let ciContext: CIContext
    private let atomicAnimal: AtomicAnimal
    private let transitionManager: VisionTransitionManager
    private let ambientEngine: AmbientEffectEngine
    private let temporalBuffer: TemporalBuffer
    private let motionAnalyzer: MotionAnalyzer
    private let parallaxManager: ParallaxManager
    private let lightDetector: LightSensitivityDetector

    private var lastFlyFrameTime: TimeInterval = 0
    private var previousRawFrame: CIImage?   // for rat motion detection (raw, unfiltered)
    
    fileprivate init(manager: CameraManager,
                     filterProcessor: AnimalFilterProcessor,
                     ciContext: CIContext,
                     atomicAnimal: AtomicAnimal,
                     transitionManager: VisionTransitionManager,
                     ambientEngine: AmbientEffectEngine,
                     temporalBuffer: TemporalBuffer,
                     motionAnalyzer: MotionAnalyzer,
                     parallaxManager: ParallaxManager,
                     lightDetector: LightSensitivityDetector) {
        self.manager = manager
        self.filterProcessor = filterProcessor
        self.ciContext = ciContext
        self.atomicAnimal = atomicAnimal
        self.transitionManager = transitionManager
        self.ambientEngine = ambientEngine
        self.temporalBuffer = temporalBuffer
        self.motionAnalyzer = motionAnalyzer
        self.parallaxManager = parallaxManager
        self.lightDetector = lightDetector
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let animal = atomicAnimal.value
        
        // Simulating Fly slow-mo by dropping frames (strobe effect ~5 fps)
        if animal == .fly {
            let now = CACurrentMediaTime()
            if now - lastFlyFrameTime < 0.20 { return }    // ~5 fps
            lastFlyFrameTime = now
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        
        // ── Raw image (always current frame) ────────────────────────────
        let rawCG = ciContext.createCGImage(ciImage, from: extent)

        // ── Filtered image with transition + ambient + dynamic focus ─────
        var filteredCI: CIImage

        if transitionManager.isTransitioning, let prevAnimal = transitionManager.previousAnimal {
            // Crossfade: blend previous and current animal filters
            let progress = transitionManager.progress
            let prevFiltered = filterProcessor.apply(animal: prevAnimal, to: ciImage)
            let newFiltered  = filterProcessor.apply(animal: animal, to: ciImage)

            // Linear interpolation via CIBlendWithAlphaMask with a constant‐color mask
            let maskColor = CIImage(color: CIColor(red: CGFloat(progress),
                                                    green: CGFloat(progress),
                                                    blue: CGFloat(progress)))
                .cropped(to: extent)

            let blend = CIFilter.blendWithMask()
            blend.inputImage = newFiltered
            blend.backgroundImage = prevFiltered
            blend.maskImage = maskColor
            filteredCI = blend.outputImage?.cropped(to: extent) ?? newFiltered
        } else {
            filteredCI = filterProcessor.apply(animal: animal, to: ciImage)
        }

        // Apply per-animal ambient effects
        let ambientParams = ambientEngine.currentParams
        filteredCI = filterProcessor.applyAmbientEffect(animal: animal, to: filteredCI, params: ambientParams)

        // Apply dynamic focus (centre sharp, edges softly blurred)
        filteredCI = filterProcessor.applyDynamicFocus(filteredCI)

        // ── Perception-based behavioral effects ─────────────────────────────

        // 🪰 Fly: ghost trails from previous frames
        if animal == .fly {
            let prev = temporalBuffer.lastFrames(3).dropFirst().map { $0 }  // skip current
            if !prev.isEmpty {
                filteredCI = filterProcessor.applyFlyGhosting(current: filteredCI, previousFrames: prev)
            }
        }

        // 🐀 Rat: motion detection — highlight movement, dim static
        if animal == .rat, let prevRaw = previousRawFrame {
            let mask = motionAnalyzer.motionMask(current: ciImage, previous: prevRaw)
            filteredCI = motionAnalyzer.applyMotionHighlight(image: filteredCI, motionMask: mask)
        }

        // 🕷️ Spider: motion detection — heavily brighten and contrast moving areas
        if animal == .spider, let prevRaw = previousRawFrame {
            let mask = motionAnalyzer.motionMask(current: ciImage, previous: prevRaw)
            filteredCI = motionAnalyzer.applySpiderMotionHighlight(image: filteredCI, motionMask: mask, rawImage: ciImage)
        }

        // 🐜 Ant: parallax shift based on device tilt
        if animal == .ant {
            let offset = parallaxManager.currentOffset
            filteredCI = filterProcessor.applyParallax(image: filteredCI, offsetX: offset.x, offsetY: offset.y)
        }

        // 🪳 Cockroach: light sensitivity flicker
        if animal == .cockroach {
            lightDetector.update(image: ciImage, context: ciContext)
            filteredCI = filterProcessor.applyCockroachFlicker(image: filteredCI, flickerIntensity: lightDetector.flickerIntensity)
        }

        // Push filtered frame into temporal buffer (for fly ghost trails)
        temporalBuffer.push(filteredCI)
        // Store raw frame for rat & spider motion detection
        previousRawFrame = ciImage

        let filteredCG = ciContext.createCGImage(filteredCI, from: extent)
        
        let rawImg      = rawCG.map      { UIImage(cgImage: $0) }
        let filteredImg = filteredCG.map { UIImage(cgImage: $0) }
        
        DispatchQueue.main.async { [weak self] in
            self?.manager?.updateImages(raw: rawImg, filtered: filteredImg)
        }
    }
}
