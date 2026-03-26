//
//  InsightPopup.swift
//  OtherEyes
//

import SwiftUI

struct InsightPopup: View {
    let animal: Animal
    @Binding var isShowing: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 60

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to dismiss
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack {
                Spacer()

                // ── Popup card ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {

                    // Drag handle pill
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 40, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    // Header row
                    HStack(alignment: .center, spacing: 12) {
                        // Glowing emoji badge
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(red: 0.55, green: 0.40, blue: 1.0).opacity(0.5),
                                            Color.clear
                                        ],
                                        center: .center, startRadius: 0, endRadius: 28
                                    )
                                )
                                .frame(width: 56, height: 56)
                            Text(animal.emoji)
                                .font(.system(size: 30))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Animal Fun Fact")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                                .textCase(.uppercase)
                                .tracking(1.2)
                            Text("Did you know?")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        // Close button
                        Button(action: dismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                    // Divider
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // Fact text — large, readable, high contrast
                    Text(animal.funFact)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    // Dismiss hint
                    Text("Swipe down or tap outside to close")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 28)
                }
                .background {
                    ZStack {
                        // Deep dark glass
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.01))
                            .background(
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.10, green: 0.08, blue: 0.20),
                                                Color(red: 0.06, green: 0.04, blue: 0.14)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        // Top highlight border
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.28), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.4), radius: 32, x: 0, y: 12)
                }
                .padding(.horizontal, 16)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 60 {
                                dismiss()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )

                Spacer().frame(height: 32)
            }
        }
        .opacity(opacity)
        .offset(y: yOffset)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                opacity = 1
                yOffset = 0
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.22)) {
            opacity = 0
            yOffset = 60
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowing = false
            dragOffset = 0
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        InsightPopup(animal: .mantisShrimp, isShowing: .constant(true))
    }
}
