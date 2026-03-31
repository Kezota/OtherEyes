//
//  FloatingPanelBackground.swift
//  OtherEyes
//

import SwiftUI

/// A reusable glassmorphism panel background with blur, gradient, and subtle border.
struct FloatingPanelBackground: View {
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.85)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.08, blue: 0.18).opacity(0.80),
                                Color(red: 0.06, green: 0.04, blue: 0.12).opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.30), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
    }
}
