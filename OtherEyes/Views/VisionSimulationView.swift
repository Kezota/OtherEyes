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
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.selectedAnimal = selectedAnimal
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: selectedAnimal) { _, newAnimal in
            cameraManager.selectedAnimal = newAnimal
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
                                Color.black        // white equivalent in mask = visible
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

                // Drag handle on the divider — lets user drag the split line directly
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)  // slider at bottom is the primary control
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
                    Text("Back")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.6), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.09), radius: 8, x: 0, y: 2)
                }
            }
            
            Spacer()
            
            // Animal name
            HStack(spacing: 6) {
                Text(selectedAnimal.emoji)
                    .font(.system(size: 16))
                Text(selectedAnimal.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.6), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.09), radius: 8, x: 0, y: 2)
            }
            
            Spacer()
            
            // Insight button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showInsight = true
                }
            }) {
                Text("💡")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.6), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.09), radius: 8, x: 0, y: 2)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Bottom Area
    private var bottomArea: some View {
        VStack(spacing: 6) {
            // Horizontal comparison slider
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
