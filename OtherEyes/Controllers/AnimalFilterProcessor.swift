//
//  AnimalFilterProcessor.swift
//  OtherEyes
//

import CoreImage
import CoreImage.CIFilterBuiltins

struct AnimalFilterProcessor: Sendable {

    nonisolated(unsafe) private let context = CIContext()

    func apply(animal: Animal, to image: CIImage) -> CIImage {
        switch animal {
        case .dog:          return applyDogFilter(image)
        case .cat:          return applyCatFilter(image)
        case .fly:          return applyFlyFilter(image)
        case .bird:         return applyBirdFilter(image)
        case .snake:        return applySnakeFilter(image)
        case .mantisShrimp: return applyMantisFilter(image)
        }
    }

    // MARK: - 🐶 Dog: Dichromatic (blue–yellow, no red)
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

        // Lower overall saturation
        let controls = CIFilter.colorControls()
        controls.inputImage = matrixOut
        controls.saturation = 0.6
        controls.brightness = 0.0
        controls.contrast   = 1.0
        return controls.outputImage ?? matrixOut
    }

    // MARK: - 🐱 Cat: Night-adapted (high exposure, desaturated, slight blur)
    private func applyCatFilter(_ image: CIImage) -> CIImage {
        // Boost exposure (tap into the shadows)
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
        exposureFilter.setValue(image, forKey: kCIInputImageKey)
        exposureFilter.setValue(NSNumber(value: 1.0), forKey: kCIInputEVKey)
        let exposed = exposureFilter.outputImage ?? image

        // Reduce saturation
        let controls = CIFilter.colorControls()
        controls.inputImage = exposed
        controls.saturation = 0.3
        controls.brightness = 0.0
        controls.contrast   = 1.15
        let desaturated = controls.outputImage ?? exposed

        // Slight blur (cats have lower spatial acuity in daylight)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = desaturated
        blur.radius     = 1.4
        return blur.outputImage?.cropped(to: image.extent) ?? desaturated
    }

    // MARK: - 🪰 Fly: Compound eye mosaic
    private func applyFlyFilter(_ image: CIImage) -> CIImage {
        // Pixellate to simulate thousands of tiny hexagonal lenses
        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = image
        pixellate.scale      = 20
        pixellate.center     = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let mosaic = pixellate.outputImage ?? image

        // Slightly saturate for the insect-UV-enhanced feel
        let controls = CIFilter.colorControls()
        controls.inputImage = mosaic
        controls.saturation = 1.1
        controls.brightness = 0.03
        controls.contrast   = 1.05
        return controls.outputImage ?? mosaic
    }

    // MARK: - 🦅 Bird: Wide-angle FOV + sharp + high contrast
    private func applyBirdFilter(_ image: CIImage) -> CIImage {
        let center  = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let radius  = Float(min(image.extent.width, image.extent.height) * 0.75)

        // Barrel distortion to mimic wide FOV
        if let bump = CIFilter(name: "CIBumpDistortion") {
            bump.setValue(image,  forKey: kCIInputImageKey)
            bump.setValue(CIVector(cgPoint: center), forKey: kCIInputCenterKey)
            bump.setValue(NSNumber(value: radius),   forKey: kCIInputRadiusKey)
            bump.setValue(NSNumber(value: -0.35),    forKey: kCIInputScaleKey)
            let distorted = (bump.outputImage ?? image).cropped(to: image.extent)

            // Sharpen luminance
            if let sharpen = CIFilter(name: "CISharpenLuminance") {
                sharpen.setValue(distorted, forKey: kCIInputImageKey)
                sharpen.setValue(NSNumber(value: 0.9), forKey: kCIInputSharpnessKey)
                let sharpened = sharpen.outputImage ?? distorted

                // High contrast + saturation (tetrachromacy colour richness)
                let controls = CIFilter.colorControls()
                controls.inputImage = sharpened
                controls.saturation = 1.8
                controls.contrast   = 1.3
                controls.brightness = 0.0
                return controls.outputImage?.cropped(to: image.extent) ?? sharpened
            }
            return distorted
        }
        return image
    }

    // MARK: - 🐍 Snake: Thermal heatmap (bright = hot/red, dark = cool/blue)
    private func applySnakeFilter(_ image: CIImage) -> CIImage {
        // Step 1: Extract luminance (greyscale)
        let grey = CIFilter.colorControls()
        grey.inputImage = image
        grey.saturation = 0
        grey.contrast   = 1.2
        let greyscale = grey.outputImage ?? image

        // Step 2: Map luminance to thermal palette
        // Bright pixels → warm (red/orange)  |  Dark pixels → cool (blue/purple)
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage   = greyscale
        matrix.rVector      = CIVector(x: 2.2,  y: 0.0, z: 0.0, w: 0)
        matrix.gVector      = CIVector(x: 0.0,  y: 0.8, z: 0.0, w: 0)
        matrix.bVector      = CIVector(x: 0.0,  y: 0.0, z: 0.25, w: 0)
        matrix.aVector      = CIVector(x: 0,    y: 0,   z: 0,   w: 1)
        matrix.biasVector   = CIVector(x: 0.0,  y: 0.0, z: 0.4, w: 0)
        let thermal = matrix.outputImage ?? greyscale

        // Step 3: Punch contrast for dramatic thermal look
        let boost = CIFilter.colorControls()
        boost.inputImage = thermal
        boost.saturation = 1.6
        boost.contrast   = 1.5
        boost.brightness = 0.0
        return boost.outputImage?.cropped(to: image.extent) ?? thermal
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
