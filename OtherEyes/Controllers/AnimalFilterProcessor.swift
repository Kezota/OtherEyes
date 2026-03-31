//
//  AnimalFilterProcessor.swift
//  OtherEyes
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct AnimalFilterProcessor: Sendable {

    private let context = CIContext()

    func apply(animal: Animal, to image: CIImage, params: AmbientEffectEngine.AmbientParams? = nil) -> CIImage {
        switch animal {
        case .dog:          return applyDogFilter(image)
        case .cat:          return applyCatFilter(image)
        case .fly:          return applyFlyFilter(image)
        case .bird:         return applyBirdFilter(image)
        case .cockroach:    return applyCockroachFilter(image)
        case .fish:         return applyFishFilter(image)
        case .mantisShrimp: return applyMantisFilter(image)
        case .eagle:        return applyEagleFilter(image)
        case .ant:          return applyAntFilter(image)
        case .spider:       return applySpiderFilter(image, params: params)
        case .rat:          return applyRatFilter(image)
        case .crocodile:    return applyCrocodileFilter(image)
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
        exposureFilter.setValue(NSNumber(value: 0.5), forKey: kCIInputEVKey)      // +0.5 EV (torch provides extra light)
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

    // MARK: - 🐟 Fish: Pincushion fisheye + blue-green underwater tint (0.5× ultra-wide)
    // "Stretch out" = pincushion distortion: center bulges outward.
    // Hardware 0.5× lens provides real wide FOV; positive bump adds the bulge.
    private func applyFishFilter(_ image: CIImage) -> CIImage {
        let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let radius = Float(min(image.extent.width, image.extent.height) * 0.90)

        // ── Pincushion / "stretch out" distortion ────────────────────────────
        // Positive scale = center pushed outward = bulging fisheye effect
        guard let bump = CIFilter(name: "CIBumpDistortion") else { return image }
        bump.setValue(image,  forKey: kCIInputImageKey)
        bump.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
        bump.setValue(NSNumber(value: radius),   forKey: kCIInputRadiusKey)
        bump.setValue(NSNumber(value: 0.55),     forKey: kCIInputScaleKey)
        let filled = (bump.outputImage ?? image).cropped(to: image.extent)

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

    // MARK: - 🦅 Eagle: Hyper-focused telescopic vision (0.5× ultra-wide lens)
    // Uses the hardware ultra-wide camera for a wider FOV, then applies strong
    // radial centre focus so the centre is razor-sharp while the surrounding
    // area falls off into soft blur — like an eagle locking onto prey.
    // Filter budget: 3 filters (radial blur + sharpen + colour controls)
    private func applyEagleFilter(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let cx = extent.midX
        let cy = extent.midY

        // ── Step 1: Radial edge blur (centre sharp → edges very soft) ───────
        // No digital zoom — the 0.5× ultra-wide lens already gives the wide field.
        // Instead we make the surrounding area soft/blurry so the centre "pops"
        // with intense clarity, simulating eagle tunnel-focus.
        let innerR = min(extent.width, extent.height) * 0.12   // ← sharp zone (12% of frame, very tight focus)
        let outerR = min(extent.width, extent.height) * 0.38   // ← blur fully kicks in at 38%
        guard let radGrad = CIFilter(name: "CIRadialGradient") else { return image }
        radGrad.setValue(CIVector(x: cx, y: cy), forKey: "inputCenter")
        radGrad.setValue(NSNumber(value: innerR), forKey: "inputRadius0")
        radGrad.setValue(NSNumber(value: outerR), forKey: "inputRadius1")
        radGrad.setValue(CIColor(red: 0, green: 0, blue: 0), forKey: "inputColor0") // centre = no blur
        radGrad.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1") // edges = max blur
        guard let mask = radGrad.outputImage?.cropped(to: extent),
              let maskedBlur = CIFilter(name: "CIMaskedVariableBlur") else { return image }
        maskedBlur.setValue(image, forKey: kCIInputImageKey)
        maskedBlur.setValue(mask, forKey: "inputMask")
        maskedBlur.setValue(NSNumber(value: 10.0), forKey: kCIInputRadiusKey) // ← edge blur radius (px), strong peripheral softening
        let focused = maskedBlur.outputImage?.cropped(to: extent) ?? image

        // ── Step 2: Centre sharpen ───────────────────────────────────────────
        // CISharpenLuminance boosts edge detail in the already-sharp centre.
        // sharpness 1.8 = extreme fovea crispness (human ≈ 0.4).
        guard let sharpen = CIFilter(name: "CISharpenLuminance") else { return focused }
        sharpen.setValue(focused, forKey: kCIInputImageKey)
        sharpen.setValue(NSNumber(value: 1.8), forKey: kCIInputSharpnessKey)  // ← sharpness intensity
        let sharpened = sharpen.outputImage ?? focused

        // ── Step 3: Contrast + vivid colours ─────────────────────────────────
        // Eagles have excellent colour vision; boost contrast and saturation
        // so the focused target really "pops" against the soft periphery.
        let controls = CIFilter.colorControls()
        controls.inputImage = sharpened
        controls.saturation = 1.45   // ← colour vividness (1.0 = normal, 1.45 = punchy)
        controls.contrast   = 1.40   // ← contrast boost (1.0 = normal)
        controls.brightness = 0.02   // ← very slight brightness lift
        return controls.outputImage?.cropped(to: extent) ?? sharpened
    }

    // MARK: - 🐜 Ant: Ground-level macro vision
    // Simulates a tiny creature's perspective — everything feels larger,
    // closer, and slightly distorted. Shallow depth of field with the
    // bottom (ground) sharper and the top (sky/background) blurrier.
    // Filter budget: 3 filters (zoom + gradient blur + colour controls)
    private func applyAntFilter(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let cx = extent.midX
        let cy = extent.midY

        // ── Step 1: Macro zoom ───────────────────────────────────────────────
        // 1.45× zoom — makes everything feel larger and closer, like being
        // an ant right up against surfaces.
        // Change this value to adjust the macro magnification (1.3 = mild, 1.6 = extreme).
        let macroScale: CGFloat = 1.45  // ← triggers 1.45× macro zoom
        let zoomIn = CGAffineTransform(translationX: cx, y: cy)
            .scaledBy(x: macroScale, y: macroScale)
            .translatedBy(x: -cx, y: -cy)
        let zoomed = image.transformed(by: zoomIn).cropped(to: extent)

        // ── Step 2: Vertical gradient blur (bottom sharp → top blurry) ──────
        // Simulates shallow depth of field: ground-level is in focus,
        // background (top of frame) falls out of focus.
        // The gradient goes from black (bottom = no blur) to white (top = blur).
        guard let linGrad = CIFilter(name: "CILinearGradient") else { return zoomed }
        // inputPoint0 = bottom of frame (sharp), inputPoint1 = top of frame (blurry)
        linGrad.setValue(CIVector(x: cx, y: extent.minY),       forKey: "inputPoint0")  // bottom
        linGrad.setValue(CIVector(x: cx, y: extent.maxY * 0.6), forKey: "inputPoint1")  // ← blur starts at 60% up
        linGrad.setValue(CIColor(red: 0, green: 0, blue: 0), forKey: "inputColor0") // bottom = sharp
        linGrad.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1") // top = blurry
        guard let gradMask = linGrad.outputImage?.cropped(to: extent),
              let maskedBlur = CIFilter(name: "CIMaskedVariableBlur") else { return zoomed }
        maskedBlur.setValue(zoomed, forKey: kCIInputImageKey)
        maskedBlur.setValue(gradMask, forKey: "inputMask")
        maskedBlur.setValue(NSNumber(value: 8.0), forKey: kCIInputRadiusKey)  // ← max blur at top (px), strong depth-of-field
        let depthBlurred = maskedBlur.outputImage?.cropped(to: extent) ?? zoomed

        // ── Step 3: Subtle lens distortion ───────────────────────────────────
        // Slight barrel distortion gives a close-up lens / macro lens feel.
        // Scale 0.15 = very subtle (0.5+ would be fisheye).
        guard let bump = CIFilter(name: "CIBumpDistortion") else { return depthBlurred }
        bump.setValue(depthBlurred, forKey: kCIInputImageKey)
        bump.setValue(CIVector(cgPoint: CGPoint(x: cx, y: cy)), forKey: kCIInputCenterKey)
        let bumpRadius = Float(min(extent.width, extent.height) * 0.7)  // ← distortion covers 70% of frame
        bump.setValue(NSNumber(value: bumpRadius), forKey: kCIInputRadiusKey)
        bump.setValue(NSNumber(value: 0.15), forKey: kCIInputScaleKey)   // ← subtle barrel warp strength
        let distorted = bump.outputImage?.cropped(to: extent) ?? depthBlurred

        // ── Step 4: Colour simplification ────────────────────────────────────
        // Ants have limited colour vision — reduce saturation and contrast
        // for a muted, earthy tone.
        let controls = CIFilter.colorControls()
        controls.inputImage = distorted
        controls.saturation = 0.55   // ← reduced colour (1.0 = normal, 0.55 = muted)
        controls.contrast   = 0.90   // ← slightly lower contrast
        controls.brightness = -0.04  // ← slightly dimmer (ground-level light)
        return controls.outputImage?.cropped(to: extent) ?? distorted
    }

    // MARK: - 🕷️ Spider: Fragmented Multiple Eyes Vision
    private func applySpiderFilter(_ image: CIImage, params: AmbientEffectEngine.AmbientParams?) -> CIImage {
        let extent = image.extent
        let cx = extent.midX
        let cy = extent.midY

        let driftX = params?.spiderDriftX ?? 0
        let driftY = params?.spiderDriftY ?? 0
        let pulse = params?.spiderPulseScale ?? 1.0

        // 1. Main Eye (Primary Focus)
        // Zoom slightly, hyper-sharp, higher contrast, and vivid warm tint
        let mainZoom = CGAffineTransform(translationX: cx, y: cy)
            .scaledBy(x: 1.08, y: 1.08)
            .translatedBy(x: -cx, y: -cy)
        var mainEye = image.transformed(by: mainZoom).cropped(to: extent)
        
        if let unsharp = CIFilter(name: "CIUnsharpMask") {
            unsharp.setValue(mainEye, forKey: kCIInputImageKey)
            unsharp.setValue(NSNumber(value: 2.5), forKey: kCIInputRadiusKey)
            unsharp.setValue(NSNumber(value: 0.8), forKey: kCIInputIntensityKey)
            mainEye = unsharp.outputImage?.cropped(to: extent) ?? mainEye
        }
        
        let controls = CIFilter.colorControls()
        controls.inputImage = mainEye
        controls.contrast = 1.15
        controls.brightness = 0.02
        controls.saturation = 1.15
        mainEye = controls.outputImage?.cropped(to: extent) ?? mainEye

        // Subtle warm tint to feel predatory
        let warmTint = CIFilter.colorMatrix()
        warmTint.inputImage = mainEye
        warmTint.rVector = CIVector(x: 1.05, y: 0.0, z: 0.0, w: 0)
        warmTint.gVector = CIVector(x: 0.0, y: 1.02, z: 0.0, w: 0)
        warmTint.bVector = CIVector(x: 0.0, y: 0.0, z: 0.95, w: 0)
        warmTint.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        mainEye = warmTint.outputImage?.cropped(to: extent) ?? mainEye

        // 2. Secondary Eyes Setup
        // Blurred, slightly desaturated, mirrored fragments
        var secondaryBase = image
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = secondaryBase
        blur.radius = 4.5
        secondaryBase = blur.outputImage?.cropped(to: extent) ?? secondaryBase

        // UV / Cool Tint (Shift towards blue/purple) + Bokeh Contrast
        let secControls = CIFilter.colorControls()
        secControls.inputImage = secondaryBase
        secControls.saturation = 0.95
        secControls.contrast = 1.05
        secControls.brightness = 0.02
        let contrastBase = secControls.outputImage?.cropped(to: extent) ?? secondaryBase
        
        let uvTint = CIFilter.colorMatrix()
        uvTint.inputImage = contrastBase
        uvTint.rVector = CIVector(x: 0.9, y: 0.0, z: 0.0, w: 0)
        uvTint.gVector = CIVector(x: 0.0, y: 1.0, z: 0.0, w: 0)
        uvTint.bVector = CIVector(x: 0.0, y: 0.0, z: 1.1, w: 0)
        uvTint.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        uvTint.biasVector = CIVector(x: 0.0, y: 0.02, z: 0.05, w: 0)
        secondaryBase = uvTint.outputImage?.cropped(to: extent) ?? contrastBase

        // Chromatic Aberration: split R and B
        let redScale = CGAffineTransform(translationX: cx, y: cy).scaledBy(x: 1.01, y: 1.01).translatedBy(x: -cx, y: -cy)
        let blueScale = CGAffineTransform(translationX: cx, y: cy).scaledBy(x: 0.99, y: 0.99).translatedBy(x: -cx, y: -cy)
        
        let redCh = CIFilter.colorMatrix()
        redCh.inputImage = secondaryBase.transformed(by: redScale).cropped(to: extent)
        redCh.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        redCh.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        redCh.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        redCh.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let redOnly = redCh.outputImage ?? secondaryBase

        let greenCh = CIFilter.colorMatrix()
        greenCh.inputImage = secondaryBase
        greenCh.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        greenCh.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
        greenCh.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        greenCh.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let greenOnly = greenCh.outputImage ?? secondaryBase

        let blueCh = CIFilter.colorMatrix()
        blueCh.inputImage = secondaryBase.transformed(by: blueScale).cropped(to: extent)
        blueCh.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        blueCh.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        blueCh.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
        blueCh.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let blueOnly = blueCh.outputImage ?? secondaryBase

        let addRG = CIFilter.additionCompositing()
        addRG.inputImage = redOnly.cropped(to: extent)
        addRG.backgroundImage = greenOnly.cropped(to: extent)
        let rg = addRG.outputImage ?? greenOnly

        let addRGB = CIFilter.additionCompositing()
        addRGB.inputImage = blueOnly.cropped(to: extent)
        addRGB.backgroundImage = rg.cropped(to: extent)
        secondaryBase = addRGB.outputImage?.cropped(to: extent) ?? secondaryBase

        // Configuration for the 6 secondary eyes:
        // (offset X, offset Y, scale X, scale Y, rotation, hue shift)
        let eyeConfigs: [(ox: CGFloat, oy: CGFloat, sx: CGFloat, sy: CGFloat, rot: CGFloat, hue: Float)] = [
            // Top Left (mirrored X/Y)
            (-0.35 * extent.width, -0.30 * extent.height, -0.95, -0.95, 0.05, -0.05),
            // Top Right (mirrored Y)
            ( 0.35 * extent.width, -0.30 * extent.height,  0.95, -0.95, -0.05, 0.05),
            // Mid Left (mirrored X, closer)
            (-0.40 * extent.width,  0.0,                  -0.90,  0.90, 0.08, -0.02),
            // Mid Right normal, closer
            ( 0.40 * extent.width,  0.0,                   0.90,  0.90, -0.08, 0.02),
            // Bottom Left (mirrored X, smaller)
            (-0.32 * extent.width,  0.30 * extent.height, -0.80,  0.80, -0.04, 0.06),
            // Bottom Right normal, smaller
            ( 0.32 * extent.width,  0.30 * extent.height,  0.80,  0.80, 0.04, -0.06)
        ]

        var comp = mainEye
        let compositeSourceOver = CIFilter.sourceOverCompositing()
        let blendMask = CIFilter.blendWithMask()

        for (i, cfg) in eyeConfigs.enumerated() {
            // Apply drift and pulse (alternate direction based on index to seem independent)
            let eyeDriftX = (i % 2 == 0) ? driftX : -driftX
            let eyeDriftY = (i < 3) ? driftY : -driftY
            let eyePulse = pulse

            // Vary each eye slightly so they don't look identical
            let hueAdjust = CIFilter.hueAdjust()
            hueAdjust.inputImage = secondaryBase
            hueAdjust.angle = cfg.hue
            
            let eyeControls = CIFilter.colorControls()
            eyeControls.inputImage = hueAdjust.outputImage ?? secondaryBase
            eyeControls.brightness = Float(0.01 * CGFloat(i % 3)) // slight brightness variance
            eyeControls.contrast = 1.0 + Float(0.02 * CGFloat(i % 2)) // slight contrast variance
            let variedEyeBase = eyeControls.outputImage?.cropped(to: extent) ?? secondaryBase

            // Transform the secondary feed for this eye
            let eyeTransform = CGAffineTransform(translationX: cx, y: cy)
                .translatedBy(x: cfg.ox + eyeDriftX, y: cfg.oy + eyeDriftY)
                .rotated(by: cfg.rot)
                .scaledBy(x: cfg.sx * eyePulse, y: cfg.sy * eyePulse)
                .translatedBy(x: -cx, y: -cy)
            
            let transformedEye = variedEyeBase.transformed(by: eyeTransform).cropped(to: extent)

            // Create soft radial mask for this eye
            // Size them to be roughly 30% of the screen width
            let radius = min(extent.width, extent.height) * 0.28
            guard let radGrad = CIFilter(name: "CIRadialGradient") else { continue }
            let centerPoint = CIVector(x: cx + cfg.ox, y: cy + cfg.oy)
            radGrad.setValue(centerPoint, forKey: "inputCenter")
            radGrad.setValue(NSNumber(value: radius * 0.4), forKey: "inputRadius0") // solid center
            radGrad.setValue(NSNumber(value: radius), forKey: "inputRadius1")       // soft fade
            radGrad.setValue(CIColor.white, forKey: "inputColor0")
            radGrad.setValue(CIColor.clear, forKey: "inputColor1")
            
            guard let mask = radGrad.outputImage?.cropped(to: extent) else { continue }

            // Apply slight global opacity to mask for blending (0.9)
            let opacity = CIFilter.colorMatrix()
            opacity.inputImage = mask
            opacity.aVector = CIVector(x: 0, y: 0, z: 0, w: 0.9)
            let softMask = opacity.outputImage?.cropped(to: extent) ?? mask

            // Composite
            blendMask.inputImage = transformedEye
            blendMask.backgroundImage = CIImage.empty().cropped(to: extent) // transparent background
            blendMask.maskImage = softMask
            let maskedEye = blendMask.outputImage?.cropped(to: extent) ?? transformedEye

            compositeSourceOver.inputImage = maskedEye
            compositeSourceOver.backgroundImage = comp
            comp = compositeSourceOver.outputImage?.cropped(to: extent) ?? comp
        }

        // 3. Deep Global Vignette over the whole compound view
        let vignette = CIFilter.vignette()
        vignette.inputImage = comp
        vignette.radius = 2.0
        vignette.intensity = 0.45 // Lighter vignette, not too dark
        return vignette.outputImage?.cropped(to: extent) ?? comp
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

    // MARK: - 🐊 Crocodile: Split half-submerged vision
    private func applyCrocodileFilter(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let cx = extent.midX
        let cy = extent.midY

        // 1. Low-angle perspective: slight zoom + vertical shift down
        let zoomScale: CGFloat = 1.15
        let transform = CGAffineTransform(translationX: cx, y: cy)
            .scaledBy(x: zoomScale, y: zoomScale)
            .translatedBy(x: -cx, y: -cy - (extent.height * 0.05)) // shift down 5%
        let zoomed = image.transformed(by: transform).cropped(to: extent)

        // 2. Top Half (Above water): Sharper, higher contrast
        var topHalf = zoomed
        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(zoomed, forKey: kCIInputImageKey)
            sharpen.setValue(NSNumber(value: 0.8), forKey: kCIInputSharpnessKey)
            topHalf = sharpen.outputImage?.cropped(to: extent) ?? zoomed
        }
        let topControls = CIFilter.colorControls()
        topControls.inputImage = topHalf
        topControls.contrast = 1.1
        topHalf = topControls.outputImage?.cropped(to: extent) ?? topHalf

        // 3. Bottom Half (Below water): Blurry, murky, dim, green/blue tint
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = zoomed
        blur.radius = 4.0
        let blurredBottom = blur.outputImage?.cropped(to: extent) ?? zoomed

        let bottomControls = CIFilter.colorControls()
        bottomControls.inputImage = blurredBottom
        bottomControls.saturation = 0.8
        bottomControls.brightness = -0.15
        bottomControls.contrast = 0.9
        let dimBottom = bottomControls.outputImage?.cropped(to: extent) ?? blurredBottom

        let tint = CIFilter.colorMatrix()
        tint.inputImage = dimBottom
        tint.rVector = CIVector(x: 0.6, y: 0.0, z: 0.0, w: 0)
        tint.gVector = CIVector(x: 0.0, y: 1.1, z: 0.0, w: 0)
        tint.bVector = CIVector(x: 0.0, y: 0.0, z: 1.2, w: 0)
        tint.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        tint.biasVector = CIVector(x: 0, y: 0.05, z: 0.1, w: 0)
        let bottomHalf = tint.outputImage?.cropped(to: extent) ?? dimBottom

        // 4. Gradient Mask for horizontal split
        // output = inputImage * maskImage + backgroundImage * (1 - maskImage)
        guard let grad = CIFilter(name: "CILinearGradient") else { return zoomed }
        grad.setValue(CIVector(x: cx, y: cy - extent.height * 0.05), forKey: "inputPoint0") // start blending slightly below center
        grad.setValue(CIVector(x: cx, y: cy + extent.height * 0.05), forKey: "inputPoint1")
        grad.setValue(CIColor.black, forKey: "inputColor0") // bottom is black (takes background -> bottomHalf)
        grad.setValue(CIColor.white, forKey: "inputColor1") // top is white (takes input -> topHalf)
        let mask = grad.outputImage?.cropped(to: extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = topHalf
        blend.backgroundImage = bottomHalf
        blend.maskImage = mask
        let splitImage = blend.outputImage?.cropped(to: extent) ?? zoomed

        // 5. Global styling
        let globalControls = CIFilter.colorControls()
        globalControls.inputImage = splitImage
        globalControls.saturation = 0.85
        globalControls.contrast = 1.05
        globalControls.brightness = -0.05
        return globalControls.outputImage?.cropped(to: extent) ?? splitImage
    }

    // MARK: - 🔍 Dynamic Focus (radial vignette blur — centre sharp, edges soft)

    func applyDynamicFocus(_ image: CIImage) -> CIImage {
        // Subtle vignette darkening at edges
        let vignette = CIFilter.vignette()
        vignette.inputImage = image
        vignette.radius     = 2.0
        vignette.intensity  = 0.35
        let vignetted = vignette.outputImage?.cropped(to: image.extent) ?? image

        // Very light Gaussian blur blended towards the edges via a radial gradient mask.
        // We create a radial gradient (white at center → black at edges) and use it
        // as a mask for CIMaskedVariableBlur.
        let center = CIVector(x: image.extent.midX, y: image.extent.midY)
        let innerRadius = min(image.extent.width, image.extent.height) * 0.35
        let outerRadius = min(image.extent.width, image.extent.height) * 0.75

        guard let radialGrad = CIFilter(name: "CIRadialGradient") else {
            return vignetted
        }
        radialGrad.setValue(center, forKey: "inputCenter")
        radialGrad.setValue(NSNumber(value: innerRadius), forKey: "inputRadius0")
        radialGrad.setValue(NSNumber(value: outerRadius), forKey: "inputRadius1")
        radialGrad.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 1), forKey: "inputColor0") // centre = no blur
        radialGrad.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1") // edges = blur

        guard let mask = radialGrad.outputImage?.cropped(to: image.extent),
              let maskedBlur = CIFilter(name: "CIMaskedVariableBlur") else {
            return vignetted
        }
        maskedBlur.setValue(vignetted, forKey: kCIInputImageKey)
        maskedBlur.setValue(mask, forKey: "inputMask")
        maskedBlur.setValue(NSNumber(value: 2.5), forKey: kCIInputRadiusKey)

        return maskedBlur.outputImage?.cropped(to: image.extent) ?? vignetted
    }

    // MARK: - 🌊 Ambient Effects (per-animal continuous subtle motion)

    func applyAmbientEffect(animal: Animal, to image: CIImage, params: AmbientEffectEngine.AmbientParams) -> CIImage {
        switch animal {
        case .fly:
            // Micro jitter — tiny translation
            let transform = CGAffineTransform(translationX: params.translationX, y: params.translationY)
            return image.transformed(by: transform).cropped(to: image.extent)

        case .fish:
            // Gentle wave — shift the existing distortion center slightly
            let center = CGPoint(
                x: image.extent.midX + params.distortionOffsetX,
                y: image.extent.midY + params.distortionOffsetY
            )
            guard let bump = CIFilter(name: "CIBumpDistortion") else { return image }
            bump.setValue(image, forKey: kCIInputImageKey)
            bump.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
            bump.setValue(NSNumber(value: Float(min(image.extent.width, image.extent.height) * 0.5)),
                          forKey: kCIInputRadiusKey)
            bump.setValue(NSNumber(value: 0.04), forKey: kCIInputScaleKey) // very subtle
            return bump.outputImage?.cropped(to: image.extent) ?? image

        case .cockroach:
            // Dim flicker — slight exposure oscillation
            guard let exposure = CIFilter(name: "CIExposureAdjust") else { return image }
            exposure.setValue(image, forKey: kCIInputImageKey)
            exposure.setValue(NSNumber(value: params.exposureDelta), forKey: kCIInputEVKey)
            return exposure.outputImage ?? image

        case .bird:
            // Zoom breathing — barely perceptible scale
            let cx = image.extent.midX
            let cy = image.extent.midY
            let s = params.scaleFactor
            let transform = CGAffineTransform(translationX: cx, y: cy)
                .scaledBy(x: s, y: s)
                .translatedBy(x: -cx, y: -cy)
            return image.transformed(by: transform).cropped(to: image.extent)

        case .mantisShrimp:
            // Slow hue drift
            guard let hue = CIFilter(name: "CIHueAdjust") else { return image }
            hue.setValue(image, forKey: kCIInputImageKey)
            hue.setValue(NSNumber(value: params.hueShift), forKey: kCIInputAngleKey)
            return hue.outputImage ?? image

        case .eagle:
            // Zoom breathing — slow, subtle focus "pulsing" like an eagle scanning
            let cx = image.extent.midX
            let cy = image.extent.midY
            // Reuse scaleFactor from AmbientParams (computed in AmbientEffectEngine)
            let s = params.eagleBreathScale
            let transform = CGAffineTransform(translationX: cx, y: cy)
                .scaledBy(x: s, y: s)
                .translatedBy(x: -cx, y: -cy)
            return image.transformed(by: transform).cropped(to: image.extent)

        case .crocodile:
            // 1. Slow vertical drift
            let drift = CGAffineTransform(translationX: 0, y: params.crocDriftY)
            let drifted = image.transformed(by: drift).cropped(to: image.extent)
            
            // 2. Ripple/wave in the bottom half
            let center = CGPoint(
                x: image.extent.midX + params.crocWaveOffset,
                y: image.extent.minY + image.extent.height * 0.25 // focus on the bottom quadrant
            )
            guard let bump = CIFilter(name: "CIBumpDistortion") else { return drifted }
            bump.setValue(drifted, forKey: kCIInputImageKey)
            bump.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
            bump.setValue(NSNumber(value: Float(image.extent.width * 0.8)), forKey: kCIInputRadiusKey)
            bump.setValue(NSNumber(value: 0.1), forKey: kCIInputScaleKey) // mild distortion
            
            return bump.outputImage?.cropped(to: image.extent) ?? drifted

        default:
            // Dog, Cat, Rat, Ant — no ambient effect
            return image
        }
    }

    // MARK: - 🪰 Fly Ghosting (blend previous frames for motion trails)

    /// Blends the current filtered frame with up to 2 previous frames
    /// at decreasing opacity, creating a ghost/trail effect for moving objects.
    func applyFlyGhosting(current: CIImage, previousFrames: [CIImage]) -> CIImage {
        var result = current
        let extent = current.extent
        // Ghost opacity: frame-1 = 30%, frame-2 = 15%
        let opacities: [Float] = [0.30, 0.15]

        for (i, prevFrame) in previousFrames.prefix(2).enumerated() {
            // Create opacity mask (constant grey)
            let alpha = opacities[i]
            let mask = CIImage(color: CIColor(red: CGFloat(alpha),
                                              green: CGFloat(alpha),
                                              blue: CGFloat(alpha)))
                .cropped(to: extent)

            // Blend: result = result * (1-alpha) + prevFrame * alpha
            let blend = CIFilter.blendWithMask()
            blend.inputImage = prevFrame.cropped(to: extent)
            blend.backgroundImage = result
            blend.maskImage = mask
            result = blend.outputImage?.cropped(to: extent) ?? result
        }
        return result
    }

    // MARK: - 🪳 Cockroach Light Flicker (exposure spike on brightness change)

    /// Applies a brief exposure boost when the LightSensitivityDetector
    /// reports a brightness spike. Fades out quickly.
    func applyCockroachFlicker(image: CIImage, flickerIntensity: Float) -> CIImage {
        guard flickerIntensity > 0.01 else { return image }

        guard let exposure = CIFilter(name: "CIExposureAdjust") else { return image }
        exposure.setValue(image, forKey: kCIInputImageKey)
        // Map flicker intensity to EV boost (max ~+1.2 EV at full flicker)
        exposure.setValue(NSNumber(value: flickerIntensity * 3.5), forKey: kCIInputEVKey)
        return exposure.outputImage ?? image
    }

    // MARK: - 🐜 Ant Parallax (gyroscope-based camera shift)

    /// Shifts the image by X/Y offsets derived from device tilt,
    /// creating a parallax depth illusion.
    func applyParallax(image: CIImage, offsetX: CGFloat, offsetY: CGFloat) -> CIImage {
        guard abs(offsetX) > 0.5 || abs(offsetY) > 0.5 else { return image }
        let shifted = image.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
        return shifted.cropped(to: image.extent)
    }
}
