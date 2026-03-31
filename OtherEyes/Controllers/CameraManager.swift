//
//  CameraManager.swift
//  OtherEyes
//

@preconcurrency import AVFoundation
import Combine
import CoreImage
import UIKit
import SwiftUI
import os
import AVFAudio

// Thread-safe box to share selectedAnimal across actor boundaries
fileprivate final class AtomicAnimal: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: Animal.dog)
    
    var value: Animal {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

// Thread-safe bool to share isFrontCamera with the frame processor
fileprivate final class AtomicBool: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)
    
    var value: Bool {
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

class CameraManager: NSObject, ObservableObject {
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue  = DispatchQueue(label: "com.othereyes.camera.session")
    private let processingQueue = DispatchQueue(label: "com.othereyes.camera.processing")

    // Shared between main and background delegate — protected by AtomicAnimal
    private let atomicAnimal = AtomicAnimal()
    private let atomicFrontCamera = AtomicBool()

    private let filterProcessor = AnimalFilterProcessor()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // ── Transition & Ambient engines ─────────────────────────────────────
    let transitionManager = VisionTransitionManager()
    let ambientEngine = AmbientEffectEngine()

    // ── Perception-based behavioral helpers ──────────────────────────────
    let temporalBuffer = TemporalBuffer(capacity: 4)
    let motionAnalyzer = MotionAnalyzer()
    let parallaxManager = ParallaxManager()
    let lightDetector = LightSensitivityDetector()

    // Retained strongly so AVFoundation delegate is never deallocated
    private var delegateWrapper: CameraDelegateWrapper?

    // Track which lens is currently active so we only switch when needed
    private var currentLensIsUltraWide: Bool = false

    @Published var filteredImage: UIImage?
    @Published var rawImage: UIImage?
    @Published var isAuthorized: Bool = false

    // Camera switch state
    @Published var isFrontCamera: Bool = false

    // Photo capture state
    @Published var capturedPhoto: UIImage? = nil
    @Published var isFreezeFrame: Bool = false

    // Shutter sound
    private var shutterPlayer: AVAudioPlayer?
    
    @Published var selectedAnimal: Animal = .dog {
        didSet {
            let oldAnimal = oldValue
            atomicAnimal.value = selectedAnimal

            // Start smooth crossfade transition
            if oldAnimal != selectedAnimal {
                transitionManager.beginTransition(from: oldAnimal, to: selectedAnimal)
                temporalBuffer.clear()
                resetProcessingState()
            }

            // Switch camera lens if the animal requires a different one (back camera only)
            if !isFrontCamera {
                let needsUltraWide = selectedAnimal.prefersUltraWide
                if needsUltraWide != currentLensIsUltraWide {
                    switchCameraLens(useUltraWide: needsUltraWide)
                }
            }

            // 🐱 Cat night-vision: turn torch on at low intensity (back camera only)
            setTorch(on: selectedAnimal == .cat && !isFrontCamera)
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
            
            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            let device = self.bestCamera(ultraWide: useUltraWide, position: position)
            guard let device,
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.currentLensIsUltraWide = useUltraWide && (device.deviceType == .builtInUltraWideCamera)

            let processor = FrameProcessor(filterProcessor: self.filterProcessor,
                                           ciContext: self.ciContext,
                                           atomicAnimal: self.atomicAnimal,
                                           atomicFrontCamera: self.atomicFrontCamera,
                                           transitionManager: self.transitionManager,
                                           ambientEngine: self.ambientEngine,
                                           temporalBuffer: self.temporalBuffer,
                                           motionAnalyzer: self.motionAnalyzer,
                                           parallaxManager: self.parallaxManager,
                                           lightDetector: self.lightDetector)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let wrapper = CameraDelegateWrapper(manager: self,
                                                    processingQueue: self.processingQueue,
                                                    processor: processor)
                self.delegateWrapper = wrapper
                self.videoOutput.setSampleBufferDelegate(wrapper, queue: self.processingQueue)
            }
            
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
            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            let device = self.bestCamera(ultraWide: useUltraWide, position: position)
            guard let device, let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            self.session.beginConfiguration()
            for input in self.session.inputs { self.session.removeInput(input) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentLensIsUltraWide = useUltraWide && (device.deviceType == .builtInUltraWideCamera)
            }
            // Re-apply rotation for back camera (front camera handles it at CIImage level)
            if !self.isFrontCamera {
                self.configureRotation()
            }
            self.session.commitConfiguration()
        }
    }

    // MARK: - Camera Switch (Front ↔ Back)
    func switchCamera() {
        isFrontCamera.toggle()
        atomicFrontCamera.value = isFrontCamera

        // Kill torch when switching to front
        if isFrontCamera {
            setTorch(on: false)
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            // Front camera never has ultra-wide
            let useUltraWide = !self.isFrontCamera && self.atomicAnimal.value.prefersUltraWide
            let device = self.bestCamera(ultraWide: useUltraWide, position: position)
            guard let device, let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            self.session.beginConfiguration()
            for input in self.session.inputs { self.session.removeInput(input) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentLensIsUltraWide = useUltraWide && (device.deviceType == .builtInUltraWideCamera)
            }
            // Only apply connection-level rotation for back camera
            if !self.isFrontCamera {
                self.configureRotation()
            }
            self.session.commitConfiguration()

            // Re-enable torch for cat on back camera
            if !self.isFrontCamera && self.atomicAnimal.value == .cat {
                self.setTorch(on: true)
            }
        }
    }

    // MARK: - Photo Capture
    func capturePhoto() {
        guard let filtered = filteredImage else { return }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Play shutter sound
        playShutterSound()

        // Freeze frame effect
        isFreezeFrame = true

        // Apply watermark + emoji overlay
        let animal = selectedAnimal
        let watermarked = PhotoOverlayRenderer.render(image: filtered, animal: animal)
        capturedPhoto = watermarked

        // Release freeze after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isFreezeFrame = false
        }
    }

    // MARK: - Shutter Sound
    private func playShutterSound() {
        guard let url = Bundle.main.url(forResource: "camera_shutter", withExtension: "mp3") else { return }
        do {
            shutterPlayer = try AVAudioPlayer(contentsOf: url)
            shutterPlayer?.volume = 0.5
            shutterPlayer?.play()
        } catch {
            // Sound unavailable — silently ignore
        }
    }

    // MARK: - Helpers
    /// Returns the best available camera. Falls back to wide-angle if ultra-wide isn't available.
    private func bestCamera(ultraWide: Bool, position: AVCaptureDevice.Position = .back) -> AVCaptureDevice? {
        if ultraWide && position == .back,
           let uw = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            return uw
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
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

    private func resetProcessingState() {
        DispatchQueue.main.async { [weak self] in
            self?.delegateWrapper?.resetForAnimalSwitch()
        }
    }

    // Called from the delegate wrapper on main thread
    func updateImages(raw: UIImage?, filtered: UIImage?) {
        if let raw      { self.rawImage      = raw }
        if let filtered { self.filteredImage = filtered }
    }
}

// MARK: - Sendable wrapper for CMSampleBuffer
fileprivate struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer
}

// MARK: - Frame Processor (runs on processingQueue)
fileprivate final class FrameProcessor: @unchecked Sendable {
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
    private var previousRawFrame: CIImage?
    private var lastFilteredImage: UIImage?

    private let atomicFrontCamera: AtomicBool

    init(filterProcessor: AnimalFilterProcessor,
         ciContext: CIContext,
         atomicAnimal: AtomicAnimal,
         atomicFrontCamera: AtomicBool,
         transitionManager: VisionTransitionManager,
         ambientEngine: AmbientEffectEngine,
         temporalBuffer: TemporalBuffer,
         motionAnalyzer: MotionAnalyzer,
         parallaxManager: ParallaxManager,
         lightDetector: LightSensitivityDetector) {
        self.filterProcessor = filterProcessor
        self.ciContext = ciContext
        self.atomicAnimal = atomicAnimal
        self.atomicFrontCamera = atomicFrontCamera
        self.transitionManager = transitionManager
        self.ambientEngine = ambientEngine
        self.temporalBuffer = temporalBuffer
        self.motionAnalyzer = motionAnalyzer
        self.parallaxManager = parallaxManager
        self.lightDetector = lightDetector
    }

    func reset() {
        lastFlyFrameTime = 0
        lastFilteredImage = nil
        previousRawFrame = nil
        temporalBuffer.clear()
    }

    func process(sampleBuffer: CMSampleBuffer, update: @escaping (UIImage?, UIImage?) -> Void) {
        let animal = atomicAnimal.value
        let now = CACurrentMediaTime()
        // Fly slow-mo interval: 0.30 seconds per frame jump
        let shouldUpdateFiltered = (animal != .fly) || (now - lastFlyFrameTime >= 0.30)

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Front camera: rotate to portrait + mirror at the CIImage level
        // (connection-level videoRotationAngle is unreliable for front camera)
        let ciImage: CIImage
        if atomicFrontCamera.value {
            ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.leftMirrored)
        } else {
            ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        }
        let extent = ciImage.extent

        // ── Raw image (always current frame) ────────────────────────────
        let rawCG = ciContext.createCGImage(ciImage, from: extent)
        let rawImg = rawCG.map { UIImage(cgImage: $0) }

        // ── Filtered image with transition + ambient + dynamic focus ─────
        var filteredImg: UIImage? = lastFilteredImage

        if shouldUpdateFiltered {
            if animal == .fly { lastFlyFrameTime = now }
            
            var filteredCI: CIImage
            let ambientParams = ambientEngine.currentParams

        if transitionManager.isTransitioning, let prevAnimal = transitionManager.previousAnimal {
            // Crossfade: blend previous and current animal filters
            let progress = transitionManager.progress
            let prevFiltered = filterProcessor.apply(animal: prevAnimal, to: ciImage, params: ambientParams)
            let newFiltered  = filterProcessor.apply(animal: animal, to: ciImage, params: ambientParams)

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
            filteredCI = filterProcessor.apply(animal: animal, to: ciImage, params: ambientParams)
        }

        // Apply per-animal ambient effects
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

        // 🐊 Crocodile: motion detection — slightly enhance moving areas
        if animal == .crocodile, let prevRaw = previousRawFrame {
            let mask = motionAnalyzer.motionMask(current: ciImage, previous: prevRaw)
            filteredCI = motionAnalyzer.applyCrocodileMotionHighlight(image: filteredCI, motionMask: mask, rawImage: ciImage)
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

            let filteredCG = ciContext.createCGImage(filteredCI, from: extent)
            filteredImg = filteredCG.map { UIImage(cgImage: $0) }
            lastFilteredImage = filteredImg

            // ── Push flattened frame into temporal buffer ─────────────────
            // We push the rendered CIImage to prevent infinite CoreImage graphs while
            // preserving the distinct chopped snapshots for the fly ghosting effect.
            if let cg = filteredCG {
                temporalBuffer.push(CIImage(cgImage: cg))
            }
        }

        // Store raw frame for spider & rat motion detection
        previousRawFrame = ciImage

        update(rawImg, filteredImg)
    }
}

// MARK: - Delegate Wrapper (nonisolated, Sendable)
// Separating the delegate into its own object avoids the Swift 6
// actor-isolation conflict on captureOutput being called from a background thread.
@MainActor
final class CameraDelegateWrapper: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    
    private weak var manager: CameraManager?
    private let processingQueue: DispatchQueue
    private let processor: FrameProcessor

    fileprivate init(manager: CameraManager,
                     processingQueue: DispatchQueue,
                     processor: FrameProcessor) {
        self.manager = manager
        self.processingQueue = processingQueue
        self.processor = processor
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var copiedBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopy(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleBufferOut: &copiedBuffer)
        guard let copiedBuffer else { return }
        let sendableBuffer = SendableSampleBuffer(buffer: copiedBuffer)
        processingQueue.async { [weak self] in
            self?.processor.process(sampleBuffer: sendableBuffer.buffer) { raw, filtered in
                DispatchQueue.main.async { [weak self] in
                    self?.manager?.updateImages(raw: raw, filtered: filtered)
                }
            }
        }
    }

    func resetForAnimalSwitch() {
        processor.reset()
    }
}
