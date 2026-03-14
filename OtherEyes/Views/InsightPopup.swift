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
    @State private var scale: CGFloat = 0.85
    
    var body: some View {
        ZStack {
            // Tap-outside dismiss area
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
            
            VStack {
                Spacer()
                
                // Popup card
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 10) {
                        Text("💡")
                            .font(.system(size: 22))
                        Text("Did you know?")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.35, green: 0.35, blue: 0.85),
                                        Color(red: 0.60, green: 0.35, blue: 0.85)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Spacer()
                        // Animal badge
                        Text(animal.emoji)
                            .font(.system(size: 18))
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                    
                    // Fact text
                    Text(animal.funFact)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.82))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Dismiss hint
                    HStack {
                        Spacer()
                        Text("Swipe down or tap outside to close")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.7))
                        Spacer()
                    }
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.9), .white.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        }
                        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
                }
                .padding(.horizontal, 20)
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                
                Spacer().frame(height: 40)
            }
        }
        .opacity(opacity)
        .scaleEffect(scale, anchor: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                opacity = 1
                scale = 1
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            opacity = 0
            scale = 0.9
            dragOffset = 80
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isShowing = false
            dragOffset = 0
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        InsightPopup(animal: .mantisShrimp, isShowing: .constant(true))
    }
}
