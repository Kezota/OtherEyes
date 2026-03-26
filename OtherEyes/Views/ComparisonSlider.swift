//
//  ComparisonSlider.swift
//  OtherEyes
//

import SwiftUI

/// Horizontal comparison slider.
/// value = 0.0 → full animal vision (divider at screen right edge)
/// value = 1.0 → full human vision  (divider at screen left edge)
struct ComparisonSlider: View {
    @Binding var value: Double
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let trackW = geo.size.width
            let thumbX = value * trackW

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.55), lineWidth: 1)
                    }
                    .frame(height: 6)

                // Left fill — animal side (purple tint)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.60, green: 0.50, blue: 0.95).opacity(0.55),
                                Color(red: 0.80, green: 0.60, blue: 1.0).opacity(0.35)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, thumbX), height: 6)

                // Thumb
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.9), .white.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 2)

                    // Mini arrows
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                }
                .frame(width: 30, height: 30)
                .offset(x: thumbX - 15)
                .scaleEffect(isDragging ? 1.12 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDragging)
            }
            .frame(height: 30)
            .contentShape(Rectangle().size(width: trackW, height: 44))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { g in
                        value = (g.location.x / trackW).clamped(to: 0...1)
                    }
            )
        }
        .frame(height: 30)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()
        ComparisonSlider(value: .constant(0.5))
            .padding(.horizontal, 24)
    }
}
