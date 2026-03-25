//
//  AnimalFilterProcessor.swift
//  OtherEyes
//

import CoreImage
import CoreImage.CIFilterBuiltins

struct AnimalFilterProcessor: Sendable {

    private let context = CIContext()

    func apply(animal: Animal, to image: CIImage) -> CIImage {
        switch animal {
        case .dog:          return applyDogFilter(image)
        case .cat:          return applyCatFilter(image)
        case .fly:          return applyFlyFilter(image)
        case .bird:         return applyBirdFilter(image)
        case .cockroach:    return applyCockroachFilter(image)
        case .fish:         return applyFishFilter(image)
        case .rat:          return applyRatFilter(image)
        case .mantisShrimp: return applyMantisFilter(image)
        }
    }

    // MARK: - 🐶 Dog: Dichromatic (blue–yellow, no red)
    // Simulates ~f/2.8 | ISO 800 | fast shutter for motion tracking
    private func applyDogFilter(_ image: CIImage) -> CIImage {
        // Color matrix: simulate dichromacy
        // Dogs have S-cones (blue) and L-cones (yellow-green), no true red.
        // Red channel → mapped to near-zero (appears dark/grey to dog)
        // Green channel → shifted toward yellow
        // Blue channel → preserved
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage   = image
        matrix.rVector      = CIVector(x: 0.18, y: 0.32, z: 0.0,  w: 0)
        matrix.gVector      = CIVector(x: 0.12, y: 0.58, z: 0.0,  w: 0)
        matrix.bVector      = CIVector(x: 0.0,  y: 0.05, z: 0.95, w: 0)
        matrix.aVector      = CIVector(x: 0,    y: 0,    z: 0,    w: 1)
        matrix.biasVector   = CIVector(x: 0,    y: 0,    z: 0,    w: 0)
        let matrixOut = matrix.outputImage ?? image

        // Lower overall saturation; slight brightness boost (wide pupil in scotopic)
        let controls = CIFilter.colorControls()
        controls.inputImage = matrixOut
        controls.saturation = 0.62
        controls.brightness = 0.04
        controls.contrast   = 1.05
        return controls.outputImage ?? matrixOut
    }

    // MARK: - 🐱 Cat: Night-adapted (high exposure, desaturated, tapetum glow, mild blur)
    // Simulates ~f/1.8 | ISO 6400 | wide pupil, low spatial acuity
    private func applyCatFilter(_ image: CIImage) -> CIImage {
        // High ISO simulation: boost exposure strongly — mimics wide pupil gathering light
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
        exposureFilter.setValue(image, forKey: kCIInputImageKey)
        exposureFilter.setValue(NSNumber(value: 1.4), forKey: kCIInputEVKey)      // +1.4 EV
        let exposed = exposureFilter.outputImage ?? image

        // Highlight clipping — mimic sensor saturation at high ISO
        let controls = CIFilter.colorControls()
        controls.inputImage = exposed
        controls.saturation = 0.22       // nearly monochromatic in dim light
        controls.brightness = 0.0
        controls.contrast   = 1.25       // higher contrast = edge pop even in low light
        let desaturated = controls.outputImage ?? exposed

        // Tapetum lucidum: slight green-cyan cast
        let tint = CIFilter.colorMatrix()
        tint.inputImage  = desaturated
        tint.rVector     = CIVector(x: 0.85, y: 0.0,  z: 0.0, w: 0)
        tint.gVector     = CIVector(x: 0.0,  y: 1.05, z: 0.0, w: 0)
        tint.bVector     = CIVector(x: 0.0,  y: 0.0, z: 0.90, w: 0)
        tint.aVector     = CIVector(x: 0,    y: 0,   z: 0,   w: 1)
        tint.biasVector  = CIVector(x: 0,    y: 0,   z: 0,   w: 0)
        let tinted = tint.outputImage ?? desaturated

        // Soft blur — cats have ~20/150 visual acuity vs humans ~20/20
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = tinted
        blur.radius     = 2.0
        return blur.outputImage?.cropped(to: image.extent) ?? tinted
    }

    // MARK: - 🪰 Fly: Compound eye mosaic (slow-motion feel, pixelated, UV-tinted)
    // Frame rate is throttled in CameraManager to 5 fps for slow-mo effect
    private func applyFlyFilter(_ image: CIImage) -> CIImage {
        // Moderate pixellate — visible facets without being overwhelming
        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = image
        pixellate.scale      = 14        // was 28 — toned down, still reads as compound eye
        pixellate.center     = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let mosaic = pixellate.outputImage ?? image

        // Slight edge blur — compound eyes have poor peripheral focus
        let edgeBlur = CIFilter.gaussianBlur()
        edgeBlur.inputImage = mosaic
        edgeBlur.radius     = 1.5
        let softened = edgeBlur.outputImage?.cropped(to: image.extent) ?? mosaic

        // UV-shifted colors — flies see into UV spectrum
        let controls = CIFilter.colorControls()
        controls.inputImage = softened
        controls.saturation = 1.3
        controls.brightness = 0.06
        controls.contrast   = 1.1
        return controls.outputImage ?? softened
    }

    // MARK: - 🐦 Bird: Wide-angle + ultra-sharp tetrachromatic vision
    // Hardware 0.5× ultra-wide lens already gives real FOV; bump adds subtle barrel warp.
    // Scale up post-distortion to fill the frame and eliminate black corners.
    private func applyBirdFilter(_ image: CIImage) -> CIImage {
        let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        // Use full shorter-dimension radius so distortion covers the whole frame
        let radius = Float(min(image.extent.width, image.extent.height) * 0.85)

        // Moderate barrel warp — hardware lens already delivers the wide FOV
        guard let bump = CIFilter(name: "CIBumpDistortion") else { return image }
        bump.setValue(image,  forKey: kCIInputImageKey)
        bump.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
        bump.setValue(NSNumber(value: radius),   forKey: kCIInputRadiusKey)
        bump.setValue(NSNumber(value: -0.40),    forKey: kCIInputScaleKey)
        let bumped = bump.outputImage ?? image

        // ── Scale up to fill corners ─────────────────────────────────────────
        // A bump with scale −S means corners need ~(1 + S*0.85) zoom to fill.
        let fillScale: CGFloat = 1.30
        let zoomIn = CGAffineTransform(translationX: center.x, y: center.y)
            .scaledBy(x: fillScale, y: fillScale)
            .translatedBy(x: -center.x, y: -center.y)
        let filled = bumped.transformed(by: zoomIn).cropped(to: image.extent)

        // High sharpness — eagles have 5× more photoreceptors per mm² than humans
        guard let sharpen = CIFilter(name: "CISharpenLuminance") else { return filled }
        sharpen.setValue(filled, forKey: kCIInputImageKey)
        sharpen.setValue(NSNumber(value: 1.4), forKey: kCIInputSharpnessKey)
        let sharpened = sharpen.outputImage ?? filled

        // Unsharp mask for extra fovea crispness
        guard let unsharp = CIFilter(name: "CIUnsharpMask") else {
            let c = CIFilter.colorControls()
            c.inputImage = sharpened; c.saturation = 2.0; c.contrast = 1.4; c.brightness = 0
            return c.outputImage?.cropped(to: image.extent) ?? sharpened
        }
        unsharp.setValue(sharpened, forKey: kCIInputImageKey)
        unsharp.setValue(NSNumber(value: 1.5), forKey: kCIInputRadiusKey)
        unsharp.setValue(NSNumber(value: 0.7), forKey: kCIInputIntensityKey)
        let crispened = unsharp.outputImage ?? sharpened

        // Tetrachromacy: vivid UV-boosted colours
        let controls = CIFilter.colorControls()
        controls.inputImage = crispened
        controls.saturation = 2.2
        controls.contrast   = 1.45
        controls.brightness = 0.02
        return controls.outputImage?.cropped(to: image.extent) ?? crispened
    }

    // MARK: - 🪳 Cockroach: Low-resolution, blurry, dim, motion-sensitive
    // Simulates poor visual acuity — relies mostly on light/dark detection
    private func applyCockroachFilter(_ image: CIImage) -> CIImage {
        // Step 1: Pixelate to simulate extremely low-resolution vision
        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = image
        pixellate.scale      = 18        // lower-res look
        pixellate.center     = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let pixelated = pixellate.outputImage ?? image

        // Step 2: Strong Gaussian blur on top of pixelation — blurry and unclear
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = pixelated
        blur.radius     = 8.0            // heavy blur
        let blurred = blur.outputImage?.cropped(to: image.extent) ?? pixelated

        // Step 3: Desaturate + dim (cockroaches are not colour-aware)
        let controls = CIFilter.colorControls()
        controls.inputImage = blurred
        controls.saturation = 0.15       // nearly greyscale
        controls.brightness = -0.12      // dim environment
        controls.contrast   = 0.85       // soft, low-contrast
        return controls.outputImage ?? blurred
    }

    // MARK: - 🐟 Fish: Barrel fisheye + blue-green underwater tint (0.5× ultra-wide)
    // "Stretch in" = barrel distortion: edges bow inward/toward center.
    // Hardware 0.5× lens provides real wide FOV; negative bump adds the curve.
    // Fill-zoom removes dark corner fringe from the warp.
    private func applyFishFilter(_ image: CIImage) -> CIImage {
        let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let radius = Float(min(image.extent.width, image.extent.height) * 0.90)

        // ── Barrel / "stretch in" distortion ─────────────────────────────────
        // Negative scale = edges pulled inward = classic fisheye barrel curve
        guard let bump = CIFilter(name: "CIBumpDistortion") else { return image }
        bump.setValue(image,  forKey: kCIInputImageKey)
        bump.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
        bump.setValue(NSNumber(value: radius),   forKey: kCIInputRadiusKey)
        bump.setValue(NSNumber(value: -0.55),    forKey: kCIInputScaleKey)
        let bumped = bump.outputImage ?? image

        // Fill-zoom to push dark fringe off-frame
        let fillScale: CGFloat = 1.25
        let zoomIn = CGAffineTransform(translationX: center.x, y: center.y)
            .scaledBy(x: fillScale, y: fillScale)
            .translatedBy(x: -center.x, y: -center.y)
        let filled = bumped.transformed(by: zoomIn).cropped(to: image.extent)

        // ── Blue-green underwater colour shift ────────────────────────────────
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage  = filled
        matrix.rVector     = CIVector(x: 0.52, y: 0.0,  z: 0.0, w: 0)
        matrix.gVector     = CIVector(x: 0.0,  y: 1.05, z: 0.0, w: 0)
        matrix.bVector     = CIVector(x: 0.0,  y: 0.0,  z: 1.25, w: 0)
        matrix.aVector     = CIVector(x: 0,    y: 0,    z: 0,   w: 1)
        matrix.biasVector  = CIVector(x: 0,    y: 0.03, z: 0.08, w: 0)
        let tinted = matrix.outputImage ?? filled

        // ── Soft peripheral vignette ──────────────────────────────────────────
        let vignette = CIFilter.vignette()
        vignette.inputImage  = tinted
        vignette.radius      = 1.6
        vignette.intensity   = 0.7
        let vignetted = vignette.outputImage?.cropped(to: image.extent) ?? tinted

        // ── Underwater grade ──────────────────────────────────────────────────
        let controls = CIFilter.colorControls()
        controls.inputImage = vignetted
        controls.saturation = 0.88
        controls.brightness = -0.07
        controls.contrast   = 1.0
        return controls.outputImage?.cropped(to: image.extent) ?? vignetted
    }

    // MARK: - 🐀 Rat: Blurry, dim, soft green-tinted vision
    // Simulates poor visual acuity with limited colour perception (blue/green)
    private func applyRatFilter(_ image: CIImage) -> CIImage {
        // Step 1: Mild blur — rats have low spatial resolution
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image
        blur.radius     = 3.5
        let blurred = blur.outputImage?.cropped(to: image.extent) ?? image

        // Step 2: Reduce contrast & saturation (muted, washed-out world)
        let controls = CIFilter.colorControls()
        controls.inputImage = blurred
        controls.saturation = 0.35        // limited colour
        controls.brightness = -0.10       // dim
        controls.contrast   = 0.88        // soft, low contrast
        let muted = controls.outputImage ?? blurred

        // Step 3: Subtle green tint overlay (blue-green colour bias)
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage  = muted
        matrix.rVector     = CIVector(x: 0.82, y: 0.0,  z: 0.0, w: 0)   // reduce red
        matrix.gVector     = CIVector(x: 0.0,  y: 1.08, z: 0.0, w: 0)   // slight green lift
        matrix.bVector     = CIVector(x: 0.0,  y: 0.0,  z: 1.0, w: 0)
        matrix.aVector     = CIVector(x: 0,    y: 0,    z: 0,   w: 1)
        matrix.biasVector  = CIVector(x: 0,    y: 0.03, z: 0.0, w: 0)   // greenish bias
        return (matrix.outputImage ?? muted).cropped(to: image.extent)
    }

    // MARK: - 🦐 Mantis Shrimp: Hyper-saturation + hue shift + chromatic aberration
    private func applyMantisFilter(_ image: CIImage) -> CIImage {
        // Max saturation
        let sat = CIFilter.colorControls()
        sat.inputImage  = image
        sat.saturation  = 3.2
        sat.contrast    = 1.1
        sat.brightness  = 0.0
        let saturated = sat.outputImage ?? image

        // Random-ish hue rotation to simulate different photoreceptor mapping
        guard let hue = CIFilter(name: "CIHueAdjust") else { return saturated }
        hue.setValue(saturated, forKey: kCIInputImageKey)
        hue.setValue(NSNumber(value: Float.pi * 0.28), forKey: kCIInputAngleKey) // 50° shift
        let hueShifted = hue.outputImage ?? saturated

        // Chromatic aberration: split R and B channels slightly
        let extent = image.extent

        let redCh = CIFilter.colorMatrix()
        redCh.inputImage  = hueShifted
        redCh.rVector     = CIVector(x: 1, y: 0, z: 0, w: 0)
        redCh.gVector     = CIVector(x: 0, y: 0, z: 0, w: 0)
        redCh.bVector     = CIVector(x: 0, y: 0, z: 0, w: 0)
        redCh.aVector     = CIVector(x: 0, y: 0, z: 0, w: 1)
        redCh.biasVector  = CIVector(x: 0, y: 0, z: 0, w: 0)
        let redOnly = (redCh.outputImage ?? hueShifted)
            .transformed(by: CGAffineTransform(translationX: 5, y: 0))

        let blueCh = CIFilter.colorMatrix()
        blueCh.inputImage = hueShifted
        blueCh.rVector    = CIVector(x: 0, y: 0, z: 0, w: 0)
        blueCh.gVector    = CIVector(x: 0, y: 0, z: 0, w: 0)
        blueCh.bVector    = CIVector(x: 0, y: 0, z: 1, w: 0)
        blueCh.aVector    = CIVector(x: 0, y: 0, z: 0, w: 1)
        blueCh.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        let blueOnly = (blueCh.outputImage ?? hueShifted)
            .transformed(by: CGAffineTransform(translationX: -5, y: 0))

        let greenCh = CIFilter.colorMatrix()
        greenCh.inputImage = hueShifted
        greenCh.rVector    = CIVector(x: 0, y: 0, z: 0, w: 0)
        greenCh.gVector    = CIVector(x: 0, y: 1, z: 0, w: 0)
        greenCh.bVector    = CIVector(x: 0, y: 0, z: 0, w: 0)
        greenCh.aVector    = CIVector(x: 0, y: 0, z: 0, w: 1)
        greenCh.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        let greenOnly = greenCh.outputImage ?? hueShifted

        let addRG = CIFilter.additionCompositing()
        addRG.inputImage      = redOnly.cropped(to: extent)
        addRG.backgroundImage = greenOnly.cropped(to: extent)
        let rg = addRG.outputImage ?? greenOnly

        let addRGB = CIFilter.additionCompositing()
        addRGB.inputImage      = blueOnly.cropped(to: extent)
        addRGB.backgroundImage = rg.cropped(to: extent)
        return addRGB.outputImage?.cropped(to: extent) ?? saturated
    }
}
