//
//  AnimalSelectionView.swift
//  OtherEyes
//

import SwiftUI
import AVFoundation

// MARK: - Press animation handled entirely by ButtonStyle (never blocks navigation)
struct GlassCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct AnimalSelectionView: View {

    @State private var path = NavigationPath()
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.92, blue: 1.0),
                        Color(red: 0.95, green: 0.94, blue: 1.0),
                        Color(red: 1.0, green: 0.96, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Decorative blobs
                Circle()
                    .fill(Color(red: 0.75, green: 0.85, blue: 1.0).opacity(0.35))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -80, y: -200)

                Circle()
                    .fill(Color(red: 0.85, green: 0.75, blue: 1.0).opacity(0.30))
                    .frame(width: 220, height: 220)
                    .blur(radius: 50)
                    .offset(x: 100, y: 200)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 6) {
                            Text("OtherEyes")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
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

                            Text("See the world through different creatures")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Animal grid
                        VStack(spacing: 12) {
                            Text("Choose your perspective")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(Animal.allCases) { animal in
                                    Button {
                                        path.append(animal)
                                    } label: {
                                        AnimalCard(animal: animal)
                                    }
                                    .buttonStyle(GlassCardButtonStyle())
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationDestination(for: Animal.self) { animal in
                VisionSimulationView(initialAnimal: animal)
            }
            .navigationBarHidden(true)
            .onAppear {
                checkCameraStatus()
            }
            
            // ── Explicit Camera Consent Overlay ──────────────────────────
            if cameraStatus == .notDetermined {
                Color.black.opacity(0.85).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                    
                    VStack(spacing: 8) {
                        Text("Camera Access Required")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("OtherEyes needs your camera to let you experience the world through different animal perspectives.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Button {
                        AVCaptureDevice.requestAccess(for: .video) { _ in
                            DispatchQueue.main.async {
                                checkCameraStatus()
                            }
                        }
                    } label: {
                        Text("Allow Camera")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 220, height: 50)
                            .background(Color.white, in: Capsule())
                    }
                    .padding(.top, 16)
                }
                .zIndex(100)
                .transition(.opacity)
            }
        }
    }

    private func checkCameraStatus() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
}

#Preview {
    AnimalSelectionView()
}
