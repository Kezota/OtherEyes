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
    @State private var showImmersionTip = false
    @State private var immersionTipId = UUID()
    @Environment(\.dismiss) private var dismiss

    // Track which animals the user has already seen insight for
    @AppStorage("visitedAnimals") private var visitedAnimalsRaw: String = ""
    @State private var pendingAutoInsightAnimal: Animal? = nil
    @State private var pendingImmersionTipForAnimal: Animal? = nil

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

            // Insight popup overlay
            if showInsight {
                InsightPopup(animal: selectedAnimal, isShowing: $showInsight)
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Immersion tip toast (below top bar)
            if showImmersionTip && !showInsight {
                VStack {
                    ImmersionTipToast(animal: selectedAnimal)
                        .id(immersionTipId)
                        .padding(.top, 64)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(4)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.selectedAnimal = selectedAnimal
            cameraManager.startSession()
            handleAnimalVisit(for: selectedAnimal)
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: selectedAnimal) { _, newAnimal in
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraManager.selectedAnimal = newAnimal
            }
            handleAnimalVisit(for: newAnimal)
        }
        .onChange(of: showInsight) { _, isShowing in
            if !isShowing {
                // When insight popup is dismissed, check if we have a pending immersion tip to show
                if let pendingAnimal = pendingImmersionTipForAnimal, pendingAnimal == selectedAnimal {
                    presentImmersionTip(for: pendingAnimal)
                    pendingImmersionTipForAnimal = nil
                }
            }
        }
    }

    // MARK: - Visited Animals Tracking
    private var visitedAnimals: Set<String> {
        Set(visitedAnimalsRaw.split(separator: ",").map(String.init))
    }

    private func markVisited(_ animal: Animal) {
        var set = visitedAnimals
        set.insert(animal.rawValue)
        visitedAnimalsRaw = set.joined(separator: ",")
    }

    private func handleAnimalVisit(for animal: Animal) {
        if !visitedAnimals.contains(animal.rawValue) {
            // First visit: Sequence insight popup, then immersion tip
            pendingImmersionTipForAnimal = animal
            pendingAutoInsightAnimal = animal
            
            // Pop insight after a short delay so view transitions finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard pendingAutoInsightAnimal == animal else { return }
                guard !showInsight else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showInsight = true
                }
                markVisited(animal)
            }
        } else {
            // Revisit: show only the immersion tip immediately
            pendingImmersionTipForAnimal = nil
            pendingAutoInsightAnimal = nil
            presentImmersionTip(for: animal)
        }
    }

    // MARK: - Immersion Tip Toast
    private func presentImmersionTip(for animal: Animal) {
        // Reset with new ID to force re-animation if already showing
        immersionTipId = UUID()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            showImmersionTip = true
        }
        // Auto-hide after 7 seconds for easier reading
        let currentId = immersionTipId
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { [self] in
            guard immersionTipId == currentId else { return }  // stale
            withAnimation(.easeOut(duration: 0.6)) {
                showImmersionTip = false
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

            // Insight button — matches top bar capsule style
            Button(action: {
                pendingAutoInsightAnimal = nil
                if !visitedAnimals.contains(selectedAnimal.rawValue) {
                    markVisited(selectedAnimal)
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showInsight = true
                }
            }) {
                HStack(spacing: 6) {
                    Text("💡")
                        .font(.system(size: 16))
                
                }
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

// MARK: - Immersion Tip Toast
struct ImmersionTipToast: View {
    let animal: Animal

    var body: some View {
        HStack(spacing: 10) {
            Text(animal.emoji)
                .font(.system(size: 20))

            Text(animal.immersionTip)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .padding(.horizontal, 24)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
