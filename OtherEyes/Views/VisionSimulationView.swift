//
//  VisionSimulationView.swift
//  OtherEyes
//

import SwiftUI

struct VisionSimulationView: View {
    let initialAnimal: Animal

    @StateObject private var cameraManager = CameraManager()
    @State private var selectedAnimal: Animal
    @State private var showInsight = false
    @State private var sliderValue: Double = 0.5  // 0 = animal, 1 = human
    @Environment(\.dismiss) private var dismiss

    // Fun Fact nudge tooltip
    @State private var showFunFactNudge = false
    @State private var nudgePulse = false
    @State private var insightPulse = false

    init(initialAnimal: Animal) {
        self.initialAnimal = initialAnimal
        _selectedAnimal = State(initialValue: initialAnimal)
    }

    var body: some View {
        ZStack {
            // Dark base for camera
            Color.black.ignoresSafeArea()

            // Camera content
            if cameraManager.isAuthorized {
                cameraContent
            } else {
                noCameraView
            }

            // Top bar overlay
            VStack {
                topBar
                Spacer()
                bottomArea
            }

            // Fun fact nudge tooltip (auto-shows then fades)
            if showFunFactNudge && !showInsight {
                VStack {
                    HStack {
                        Spacer()
                        FunFactNudge(onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showFunFactNudge = false
                                showInsight = true
                            }
                        })
                        .padding(.trailing, 16)
                        .padding(.top, 72)
                    }
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(5)
            }

            // Insight popup overlay
            if showInsight {
                InsightPopup(animal: selectedAnimal, isShowing: $showInsight)
                    .zIndex(10)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.selectedAnimal = selectedAnimal
            cameraManager.startSession()
            scheduleNudge()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: selectedAnimal) { _, newAnimal in
            cameraManager.selectedAnimal = newAnimal
            // Re-trigger nudge each time the user switches animal
            showFunFactNudge = false
            scheduleNudge()
        }
        .onChange(of: showInsight) { _, open in
            if !open { scheduleNudge(delay: 20) }   // nudge again after closing
        }
    }

    // MARK: - Nudge Scheduling
    private func scheduleNudge(delay: TimeInterval = 5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !showInsight else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showFunFactNudge = true
            }
            // Auto-hide nudge after 8 s if not tapped
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showFunFactNudge = false
                }
            }
        }
    }

    // MARK: - Camera Content
    @ViewBuilder
    private var cameraContent: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: Animal vision — full frame
                if let filtered = cameraManager.filteredImage {
                    Image(uiImage: filtered)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }

                // Layer 2: Human vision — clipped to RIGHT portion
                if let raw = cameraManager.rawImage {
                    let xOffset = geo.size.width * sliderValue
                    let humanWidth = geo.size.width - xOffset

                    Image(uiImage: raw)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .mask(
                            HStack(spacing: 0) {
                                Color.clear
                                    .frame(width: xOffset)
                                Color.black
                                    .frame(width: humanWidth)
                            }
                        )

                    // Vertical divider line
                    Rectangle()
                        .fill(.white.opacity(0.75))
                        .frame(width: 2, height: geo.size.height)
                        .position(x: xOffset, y: geo.size.height / 2)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
            }
        }
    }

    // MARK: - No Camera Access
    private var noCameraView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera access required")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Please enable camera in Settings")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(alignment: .center) {
            // Back button
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.4), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
                }
            }

            Spacer()

            // Animal name
            HStack(spacing: 6) {
                Text(selectedAnimal.emoji)
                    .font(.system(size: 16))
                Text(selectedAnimal.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
            }

            Spacer()

            // Insight button — pulses to draw attention
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showFunFactNudge = false
                    showInsight = true
                }
            }) {
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color(red: 0.75, green: 0.55, blue: 1.0).opacity(insightPulse ? 0.0 : 0.55), lineWidth: 2)
                        .scaleEffect(insightPulse ? 1.55 : 1.0)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: insightPulse
                        )
                        .frame(width: 44, height: 44)

                    Text("💡")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Circle()
                                        .stroke(Color(red: 0.75, green: 0.55, blue: 1.0).opacity(0.6), lineWidth: 1.5)
                                }
                                .shadow(color: Color(red: 0.55, green: 0.30, blue: 1.0).opacity(0.5), radius: 10, x: 0, y: 0)
                        }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    insightPulse = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Bottom Area
    private var bottomArea: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("👁")
                    .font(.system(size: 14))
                ComparisonSlider(value: $sliderValue)
                Text(selectedAnimal.emoji)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            AnimalSwitcherBar(selectedAnimal: $selectedAnimal)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Fun Fact Nudge Tooltip
struct FunFactNudge: View {
    let onTap: () -> Void

    @State private var bounce = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text("💡")
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Animal Fun Fact")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Tap to discover!")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.20, blue: 0.75),
                                Color(red: 0.55, green: 0.25, blue: 0.90)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    }
                    .shadow(color: Color(red: 0.45, green: 0.20, blue: 0.85).opacity(0.6), radius: 14, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
        .offset(y: bounce ? -3 : 0)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bounce)
        .onAppear { bounce = true }
    }
}
