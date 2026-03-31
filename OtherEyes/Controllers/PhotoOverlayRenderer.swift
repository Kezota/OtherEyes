//
//  PhotoOverlayRenderer.swift
//  OtherEyes
//

import UIKit

/// Draws watermark text and animal emoji onto a captured photo using UIGraphicsImageRenderer.
struct PhotoOverlayRenderer {

    /// Renders the "OtherEyes" watermark and perspective text onto the given image.
    /// - Parameters:
    ///   - image: The base captured image (already filtered).
    ///   - animal: The currently selected animal (provides the emoji and name).
    /// - Returns: A new UIImage with overlays composited.
    static func render(image: UIImage, animal: Animal) -> UIImage {
        let size = image.size
        let scale = image.scale

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            // Draw the base image
            image.draw(at: .zero)

            // ── Layout constants (scaled to image resolution) ────────────
            let padding: CGFloat = 24 * scale
            let appNameFontSize: CGFloat = 44 * scale
            let perspectiveFontSize: CGFloat = 28 * scale
            let emojiFontSize: CGFloat = 80 * scale

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            shadow.shadowOffset = CGSize(width: 1, height: 1)
            shadow.shadowBlurRadius = 5

            // ── App name: "OtherEyes" — larger, bold ─────────────────────
            let appNameText = "OtherEyes"
            let appNameFont = UIFont.systemFont(ofSize: appNameFontSize, weight: .bold)
            let appNameAttrs: [NSAttributedString.Key: Any] = [
                .font: appNameFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.65),
                .shadow: shadow
            ]
            let appNameSize = (appNameText as NSString).size(withAttributes: appNameAttrs)

            let appNameX = size.width - appNameSize.width - padding
            let appNameY = size.height - appNameSize.height - padding

            (appNameText as NSString).draw(
                at: CGPoint(x: appNameX, y: appNameY),
                withAttributes: appNameAttrs
            )

            // ── Perspective text: "Viewing from Dog's eyes 🐶" ───────────
            let perspectiveText = "Viewing from \(animal.name)'s eyes"
            let perspectiveFont = UIFont.systemFont(ofSize: perspectiveFontSize, weight: .medium)
            let perspectiveAttrs: [NSAttributedString.Key: Any] = [
                .font: perspectiveFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.55),
                .shadow: shadow
            ]
            let perspectiveSize = (perspectiveText as NSString).size(withAttributes: perspectiveAttrs)

            // Position above app name, right-aligned
            let perspectiveX = size.width - perspectiveSize.width - padding
            let perspectiveY = appNameY - perspectiveSize.height - (4 * scale)

            (perspectiveText as NSString).draw(
                at: CGPoint(x: perspectiveX, y: perspectiveY),
                withAttributes: perspectiveAttrs
            )

            // ── Larger emoji accent (top-right of the text block) ────────
            let emojiText = animal.emoji
            let emojiFont = UIFont.systemFont(ofSize: emojiFontSize)
            let emojiAttrs: [NSAttributedString.Key: Any] = [
                .font: emojiFont
            ]
            let emojiSize = (emojiText as NSString).size(withAttributes: emojiAttrs)

            let emojiX = size.width - emojiSize.width - padding
            let emojiY = perspectiveY - emojiSize.height - (4 * scale)

            (emojiText as NSString).draw(
                at: CGPoint(x: emojiX, y: emojiY),
                withAttributes: emojiAttrs
            )
        }
    }
}
