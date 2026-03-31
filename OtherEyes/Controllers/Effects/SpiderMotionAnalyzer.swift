//
//  MotionAnalyzer.swift
//  OtherEyes
//
//  Lightweight frame-differencing engine for Spider & Rat vision.
//  Compares the current frame to the previous to produce a motion mask
//  that highlights areas where pixels changed (movement).
//

import CoreImage
import CoreImage.CIFilterBuiltins

struct MotionAnalyzer: Sendable {

    /// Produces a greyscale motion mask from the difference between two frames.
    /// White = movement, Black = static. The mask is thresholded and blurred
    /// to avoid noisy pixel-level flickering.
    func motionMask(current: CIImage, previous: CIImage) -> CIImage {
        let extent = current.extent

        // Step 1: absolute difference between frames
        let diff = CIFilter.differenceBlendMode()
        diff.inputImage = current
        diff.backgroundImage = previous
        let rawDiff = diff.outputImage?.cropped(to: extent) ?? current

        // Step 2: desaturate to greyscale (we only care about luminance diff)
        let grey = CIFilter.colorControls()
        grey.inputImage = rawDiff
        grey.saturation = 0          // fully greyscale
        grey.brightness = 0.05      // slight lift so subtle motion is visible
        grey.contrast   = 3.0        // amplify differences (threshold effect)
        let mask = grey.outputImage?.cropped(to: extent) ?? rawDiff

        // Step 3: blur the mask to avoid pixel-level noise
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask
        blur.radius     = 4.0        // smooth the mask
        return blur.outputImage?.cropped(to: extent) ?? mask
    }

    /// Apply the motion mask to the filtered image:
    /// - Moving areas → full brightness/contrast
    /// - Static areas → dimmed and desaturated
    func applyMotionHighlight(image: CIImage, motionMask: CIImage) -> CIImage {
        let extent = image.extent

        // Create a dimmed version of the image (static areas)
        let dimmed = CIFilter.colorControls()
        dimmed.inputImage = image
        dimmed.saturation = 0.25     // very desaturated
        dimmed.brightness = -0.12    // darker
        dimmed.contrast   = 0.80     // low contrast
        let staticVersion = dimmed.outputImage?.cropped(to: extent) ?? image

        // Blend: where mask is white (motion) → show original; where black (static) → show dimmed
        let blend = CIFilter.blendWithMask()
        blend.inputImage = image              // motion areas (bright)
        blend.backgroundImage = staticVersion  // static areas (dim)
        blend.maskImage = motionMask
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    /// Apply the motion mask for Spider vision:
    /// - Moving areas in the periphery → heavily brightened and high contrast
    /// - Static areas and center → show the original filtered view
    func applySpiderMotionHighlight(image: CIImage, motionMask: CIImage, rawImage: CIImage) -> CIImage {
        let extent = image.extent
        let cx = extent.midX
        let cy = extent.midY

        // Create a brightened, sharper version of the raw image for the moving parts
        let brighten = CIFilter.colorControls()
        brighten.inputImage = rawImage
        brighten.brightness = 0.35     // huge exposure blow-out
        brighten.contrast = 1.60       // extreme contrast
        brighten.saturation = 1.80     // super saturated for an electric feel
        let brightRaw = brighten.outputImage?.cropped(to: extent) ?? rawImage

        // Add a "bloom" / glow effect to the brightly lit motion
        let bloomBlur = CIFilter.gaussianBlur()
        bloomBlur.inputImage = brightRaw
        bloomBlur.radius = 12.0
        let blurredBright = bloomBlur.outputImage?.cropped(to: extent) ?? brightRaw

        let bloomAdd = CIFilter.additionCompositing()
        bloomAdd.inputImage = blurredBright
        bloomAdd.backgroundImage = brightRaw
        let glowingMotion = bloomAdd.outputImage?.cropped(to: extent) ?? brightRaw

        // Restrict motion highlight to the periphery (secondary eyes)
        // Center (main eye) should stay relatively stable
        let radius = min(extent.width, extent.height) * 0.45
        guard let radGrad = CIFilter(name: "CIRadialGradient") else { return image }
        radGrad.setValue(CIVector(x: cx, y: cy), forKey: "inputCenter")
        radGrad.setValue(NSNumber(value: radius * 0.4), forKey: "inputRadius0") // black in center
        radGrad.setValue(NSNumber(value: radius), forKey: "inputRadius1")       // white on edges
        radGrad.setValue(CIColor.black, forKey: "inputColor0")
        radGrad.setValue(CIColor.white, forKey: "inputColor1")
        
        let peripheralMask = radGrad.outputImage?.cropped(to: extent) ?? motionMask

        // Combine motion mask with the peripheral mask (Multiply)
        let multiply = CIFilter.multiplyBlendMode()
        multiply.inputImage = motionMask
        multiply.backgroundImage = peripheralMask
        let finalMotionMask = multiply.outputImage?.cropped(to: extent) ?? motionMask

        // Blend: motion areas get the bright glowing version, static keep the base image
        let blend = CIFilter.blendWithMask()
        blend.inputImage = glowingMotion
        blend.backgroundImage = image
        blend.maskImage = finalMotionMask
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    /// Apply the motion mask for Crocodile vision:
    /// - Moving areas → slightly enhanced brightness and clarity
    /// - Static areas → show the original filtered view
    func applyCrocodileMotionHighlight(image: CIImage, motionMask: CIImage, rawImage: CIImage) -> CIImage {
        let extent = image.extent

        // Enhance clarity / brightness slightly for moving areas
        let brighten = CIFilter.colorControls()
        brighten.inputImage = rawImage
        brighten.brightness = 0.08
        brighten.contrast = 1.15
        brighten.saturation = 1.10
        let brightRaw = brighten.outputImage?.cropped(to: extent) ?? rawImage

        var enhancedMotion = brightRaw
        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(brightRaw, forKey: kCIInputImageKey)
            sharpen.setValue(NSNumber(value: 0.9), forKey: kCIInputSharpnessKey)
            enhancedMotion = sharpen.outputImage?.cropped(to: extent) ?? brightRaw
        }

        // Blend: motion areas get enhanced version, static get the crocodile filter
        let blend = CIFilter.blendWithMask()
        blend.inputImage = enhancedMotion
        blend.backgroundImage = image
        blend.maskImage = motionMask
        return blend.outputImage?.cropped(to: extent) ?? image
    }
}
