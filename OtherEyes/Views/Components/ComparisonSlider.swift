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

    // Haptic feedback
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    @State private var lastHapticStep: Int = -1

    var body: some View {
        GeometryReader { geo in
            let trackW = geo.size.width
            let thumbX = value * trackW

            ZStack(alignment: .leading) {
                // Track background — glass material with soft shadow
                Capsule()
                    .fill(.regularMaterial.opacity(0.6))
                    .overlay {
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
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

                // Thumb — glass with highlight edge and soft shadow
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white.opacity(0.15), .clear],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: 18
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.85), .white.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
                        .shadow(color: Color(red: 0.6, green: 0.5, blue: 1.0).opacity(isDragging ? 0.3 : 0), radius: 12, x: 0, y: 0)

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
                .scaleEffect(isDragging ? 1.15 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.55), value: isDragging)
            }
            .frame(height: 30)
            .contentShape(Rectangle().size(width: trackW, height: 44))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { g in
                        let newValue = (g.location.x / trackW).clamped(to: 0...1)
                        value = newValue

                        // Haptic on every 10% step
                        let step = Int(newValue * 10)
                        if step != lastHapticStep {
                            lastHapticStep = step
                            feedbackGenerator.selectionChanged()
                        }
                    }
            )
        }
        .frame(height: 30)
        .onAppear {
            feedbackGenerator.prepare()
        }
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
