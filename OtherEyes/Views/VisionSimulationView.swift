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

    // NEW: Shutter flash
    @State private var shutterFlash: Bool = false

    // NEW: Animal dropdown
    @State private var showAnimalPicker = false
    @State private var dropdownFromHeader = false

    // Inline divider drag state
    @State private var isDraggingDivider = false
    @State private var lastDividerHapticStep: Int = -1
    private let dividerFeedback = UISelectionFeedbackGenerator()

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

            // NEW: Shutter flash overlay
            if shutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(15)
            }

            // NEW: Photo preview overlay
            if let captured = cameraManager.capturedPhoto {
                PhotoPreviewView(
                    image: captured,
                    animal: selectedAnimal,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            cameraManager.capturedPhoto = nil
                        }
                    }
                )
                .zIndex(20)
                .transition(.opacity)
            }

            // NEW: Animal picker dropdown overlay (high zIndex, fixed position)
            if showAnimalPicker {
                // Tap-outside-to-dismiss background
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showAnimalPicker = false
                        }
                    }
                    .zIndex(29)

                if dropdownFromHeader {
                    // Dropdown anchored below the header (top-center)
                    VStack {
                        animalDropdown
                            .padding(.top, 56)
                        Spacer()
                    }
                    .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                    .zIndex(30)
                } else {
                    // Dropdown panel anchored to bottom-left
                    VStack {
                        Spacer()
                        HStack {
                            animalDropdown
                                .padding(.leading, 28)
                                .padding(.bottom, 100)
                            Spacer()
                        }
                    }
                    .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
                    .zIndex(30)
                }
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
        .onChange(of: selectedAnimal) { newAnimal in
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraManager.selectedAnimal = newAnimal
            }
            handleAnimalVisit(for: newAnimal)
        }
        .onChange(of: showInsight) { isShowing in
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
                }

                // ── Inline divider + draggable handle ────────────────────
                let xPos = geo.size.width * sliderValue

                // Vertical divider line
                Rectangle()
                    .fill(.white.opacity(0.8))
                    .frame(width: 2.5, height: geo.size.height)
                    .shadow(color: .black.opacity(0.4), radius: 6)
                    .position(x: xPos, y: geo.size.height / 2)
                    .allowsHitTesting(false)

                // Draggable handle knob on the divider
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white.opacity(0.2), .clear],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: 20
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.9), .white.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 3)
                        .shadow(color: .white.opacity(isDraggingDivider ? 0.25 : 0), radius: 14)

                    // Left/right arrows inside
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 36, height: 36)
                .scaleEffect(isDraggingDivider ? 1.18 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.55), value: isDraggingDivider)
                .position(x: xPos, y: geo.size.height / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            isDraggingDivider = true
                            let newValue = min(max(g.location.x / geo.size.width, 0), 1)
                            sliderValue = newValue

                            // Haptic at every 10% step
                            let step = Int(newValue * 10)
                            if step != lastDividerHapticStep {
                                lastDividerHapticStep = step
                                dividerFeedback.selectionChanged()
                            }
                        }
                        .onEnded { _ in
                            isDraggingDivider = false
                        }
                )

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

            // Animal name (tappable → opens dropdown)
            Button {
                dropdownFromHeader = true
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showAnimalPicker.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedAnimal.emoji)
                        .font(.system(size: 16))
                    Text(selectedAnimal.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(showAnimalPicker && dropdownFromHeader ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: showAnimalPicker)
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
            }

            Spacer()

            // Insight button
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
        VStack(spacing: 12) {
            // Bottom control bar: [animal picker]  [capture]  [camera flip]
            ZStack {
                HStack {
                    // Left: Animal emoji picker
                    animalPickerButton
                    Spacer()
                    // Right: Camera switch
                    cameraFlipButton
                }

                // Center: Capture button
                captureButton
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Animal Picker Button
    private var animalPickerButton: some View {
        Button(action: {
            dropdownFromHeader = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                showAnimalPicker.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
                    .frame(width: 50, height: 50)

                Text(selectedAnimal.emoji)
                    .font(.system(size: 24))
            }
        }
    }

    // MARK: - Animal Dropdown
    private var animalDropdown: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(Animal.allCases) { animal in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedAnimal = animal
                            showAnimalPicker = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(animal.emoji)
                                .font(.system(size: 22))
                            Text(animal.name)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            if animal == selectedAnimal {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(animal == selectedAnimal
                                      ? Color.white.opacity(0.12)
                                      : Color.clear)
                        )
                    }
                    .buttonStyle(AnimalRowButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 185, height: 320)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.10, blue: 0.22).opacity(0.92),
                                    Color(red: 0.08, green: 0.06, blue: 0.16).opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Camera Flip Button
    private var cameraFlipButton: some View {
        Button(action: {
            cameraManager.switchCamera()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
                    .frame(width: 50, height: 50)

                Image(systemName: "camera.rotate")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(CameraFlipButtonStyle())
    }

    // MARK: - Capture Button
    private var captureButton: some View {
        Button(action: {
            triggerCapture()
        }) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)

                Circle()
                    .fill(.white)
                    .frame(width: 58, height: 58)
                    .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)
            }
        }
        .buttonStyle(ShutterButtonStyle())
    }

    // MARK: - Capture Logic
    private func triggerCapture() {
        withAnimation(.easeIn(duration: 0.08)) {
            shutterFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.25)) {
                shutterFlash = false
            }
        }
        cameraManager.capturePhoto()
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

// MARK: - Shutter Button Style
struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Camera Flip Button Style
struct CameraFlipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Animal Row Button Style (press highlight for dropdown items)
struct AnimalRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? Color.white.opacity(0.15) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .padding(.horizontal, 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
