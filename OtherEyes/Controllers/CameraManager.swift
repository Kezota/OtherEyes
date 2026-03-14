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

    // Retained strongly so AVFoundation delegate is never deallocated
    nonisolated(unsafe) private var delegateWrapper: CameraDelegateWrapper?

    @Published var filteredImage: UIImage?
    @Published var rawImage: UIImage?
    @Published var isAuthorized: Bool = false
    
    @Published var selectedAnimal: Animal = .dog {
        didSet { atomicAnimal.value = selectedAnimal }
    }
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            
            self.session.addInput(input)
            
            // Delegate is set to the nonisolated wrapper
            let wrapper = CameraDelegateWrapper(manager: self,
                                                filterProcessor: self.filterProcessor,
                                                ciContext: self.ciContext,
                                                atomicAnimal: self.atomicAnimal)
            self.delegateWrapper = wrapper          // ← retain it!
            self.videoOutput.setSampleBufferDelegate(wrapper, queue: self.processingQueue)
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
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

    private var lastFlyFrameTime: TimeInterval = 0
    
    fileprivate init(manager: CameraManager, filterProcessor: AnimalFilterProcessor, ciContext: CIContext, atomicAnimal: AtomicAnimal) {
        self.manager = manager
        self.filterProcessor = filterProcessor
        self.ciContext = ciContext
        self.atomicAnimal = atomicAnimal
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let animal = atomicAnimal.value
        
        // Simulating Fly slow-mo by dropping frames (strobe effect ~8 fps)
        if animal == .fly {
            let now = CACurrentMediaTime()
            if now - lastFlyFrameTime < 0.12 { return }
            lastFlyFrameTime = now
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let rawCG      = ciContext.createCGImage(ciImage, from: ciImage.extent)
        let filteredCI = filterProcessor.apply(animal: animal, to: ciImage)
        let filteredCG = ciContext.createCGImage(filteredCI, from: ciImage.extent)
        
        let rawImg      = rawCG.map      { UIImage(cgImage: $0) }
        let filteredImg = filteredCG.map { UIImage(cgImage: $0) }
        
        DispatchQueue.main.async { [weak self] in
            self?.manager?.updateImages(raw: rawImg, filtered: filteredImg)
        }
    }
}
