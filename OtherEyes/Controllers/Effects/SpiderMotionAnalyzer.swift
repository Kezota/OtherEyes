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
    /// - Moving areas → heavily brightened and high contrast
    /// - Static areas → show the original (fragmented/dimmed) filtered view
    func applySpiderMotionHighlight(image: CIImage, motionMask: CIImage, rawImage: CIImage) -> CIImage {
        let extent = image.extent

        // Create a brightened, sharper version of the raw image for the moving parts
        let brighten = CIFilter.colorControls()
        brighten.inputImage = rawImage
        brighten.brightness = 0.15     // lift shadows
        brighten.contrast = 1.35       // strong contrast
        brighten.saturation = 1.25     // slight color boost
        let brightRaw = brighten.outputImage?.cropped(to: extent) ?? rawImage

        // Blend: motion areas get the bright raw version, static keep the fragmented base
        let blend = CIFilter.blendWithMask()
        blend.inputImage = brightRaw
        blend.backgroundImage = image
        blend.maskImage = motionMask
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
