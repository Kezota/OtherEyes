//
//  InstructionView.swift
//  OtherEyes
//

import SwiftUI

struct InstructionView: View {
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss
    
    private let steps = [
        InteractiveInstructionStep(
            title: "Welcome to OtherEyes",
            description: "Explore how animals see the world through your camera. Each animal perceives light, color, and motion differently.",
            highlightArea: .none
        ),
        InteractiveInstructionStep(
            title: "Back Button",
            description: "Tap here to return to animal selection at any time.",
            highlightArea: .backButton
        ),
        InteractiveInstructionStep(
            title: "Insight Button",
            description: "Tap the lightbulb to discover fun facts about how each animal's eyes work.",
            highlightArea: .insightButton
        ),
        InteractiveInstructionStep(
            title: "Comparison Slider",
            description: "Drag this slider to compare animal vision (left) with human vision (right). Watch the scene transform as you slide.",
            highlightArea: .comparisonSlider
        ),
        InteractiveInstructionStep(
            title: "Camera View",
            description: "This is the live camera feed showing how the selected animal sees the world in real-time.",
            highlightArea: .cameraView
        ),
        InteractiveInstructionStep(
            title: "Animal Switcher",
            description: "Tap any animal emoji at the bottom to instantly switch perspectives. Watch how the same scene looks completely different!",
            highlightArea: .animalSwitcher
        ),
        InteractiveInstructionStep(
            title: "Ready to Explore?",
            description: "You're all set! Pick an animal and start comparing its vision to your own. Move around, point at things, and discover how different creatures perceive the world.",
            highlightArea: .none
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Mock app preview
                mockVisionView
                    .ignoresSafeArea(edges: .top)

                // Bottom instruction panel
                VStack(spacing: 16) {
                    // Title
                    Text(steps[currentStep].title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    // Description
                    Text(steps[currentStep].description)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.5)

                    Spacer(minLength: 12)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))

                            Capsule()
                                .fill(Color.accentColor.opacity(0.6))
                                .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(steps.count))
                        }
                    }
                    .frame(height: 3)

                    // Navigation
                    HStack(spacing: 12) {
                        if currentStep > 0 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep -= 1
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.thinMaterial)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                        }

                        if currentStep < steps.count - 1 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 6) {
                                    Text("Got it!")
                                    Image(systemName: "checkmark")
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(12)
            }
        }
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private var mockVisionView: some View {
        ZStack {
            // Mock camera view
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.5),
                    Color(red: 0.15, green: 0.25, blue: 0.45)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 0) {
                // Top controls
                HStack(spacing: 10) {
                    highlightBox(
                        isHighlighted: steps[currentStep].highlightArea == .backButton,
                        content: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    )
                    
                    Spacer()
                    
                    highlightBox(
                        isHighlighted: steps[currentStep].highlightArea == .insightButton,
                        content: {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    )
                }
                .padding(12)
                
                Spacer()
                
                // Comparison slider (above animal switcher)
                if steps[currentStep].highlightArea == .comparisonSlider {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Text("🐾")
                                .font(.system(size: 12))
                            
                            highlightBox(
                                isHighlighted: true,
                                content: {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                            
                                            Capsule()
                                                .fill(Color(red: 0.6, green: 0.5, blue: 0.95).opacity(0.6))
                                                .frame(width: geo.size.width * 0.4)
                                            
                                            Circle()
                                                .fill(Color.white.opacity(0.4))
                                                .frame(width: 20)
                                                .offset(x: geo.size.width * 0.4 - 10)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            )
                            
                            Text("👁️")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                } else {
                    HStack(spacing: 8) {
                        Text("🐾")
                            .font(.system(size: 12))
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                
                                Capsule()
                                    .fill(Color(red: 0.6, green: 0.5, blue: 0.95).opacity(0.6))
                                    .frame(width: geo.size.width * 0.4)
                                
                                Circle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: 20)
                                    .offset(x: geo.size.width * 0.4 - 10)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("👁️")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                
                // Animal switcher
                if steps[currentStep].highlightArea == .animalSwitcher {
                    highlightBox(
                        isHighlighted: true,
                        content: {
                            HStack(spacing: 8) {
                                ForEach(["🐶", "🐱", "🪰", "🦅", "🐍", "🦐"], id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.system(size: 16))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                Spacer()
                            }
                        }
                    )
                    .padding(12)
                } else {
                    HStack(spacing: 8) {
                        ForEach(["🐶", "🐱", "🪰", "🦅", "🐍", "🦐"], id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 16))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding(12)
                }
            }
            
            // Camera view highlight
            if steps[currentStep].highlightArea == .cameraView {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.6, green: 0.5, blue: 0.95), lineWidth: 2)
                    .padding(8)
                    .overlay(
                        VStack {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Live Camera")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Real-time animal vision")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                                
                                Spacer()
                            }
                            .padding(12)
                            
                            Spacer()
                        }
                    )
            }
        }
    }
    
    @ViewBuilder
    private func highlightBox(isHighlighted: Bool, content: () -> some View) -> some View {
        if isHighlighted {
            content()
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.5, blue: 0.95),
                                    Color(red: 0.8, green: 0.6, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(red: 0.6, green: 0.5, blue: 0.95).opacity(0.5), radius: 8, x: 0, y: 0)
                .scaleEffect(1.05)
        } else {
            content()
        }
    }
}

struct InteractiveInstructionStep {
    let title: String
    let description: String
    let highlightArea: HighlightArea
    
    enum HighlightArea {
        case none
        case backButton
        case insightButton
        case comparisonSlider
        case cameraView
        case animalSwitcher
    }
}

#Preview {
    InstructionView()
}
