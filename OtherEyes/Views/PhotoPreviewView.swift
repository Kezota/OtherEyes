//
//  PhotoPreviewView.swift
//  OtherEyes
//

import SwiftUI
import Photos

struct PhotoPreviewView: View {
    let image: UIImage
    let animal: Animal
    let onDismiss: () -> Void

    @State private var showSavedConfirmation = false
    @State private var appearAnimation = false
    @State private var saveScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
                .opacity(appearAnimation ? 1 : 0)

            // Photo display
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 60)
                .padding(.bottom, 120)
                .scaleEffect(appearAnimation ? 1 : 0.85)
                .opacity(appearAnimation ? 1 : 0)

            // Top bar — close button
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    }
                            }
                    }
                    .padding(.leading, 16)

                    Spacer()

                    // Animal badge
                    HStack(spacing: 6) {
                        Text(animal.emoji)
                            .font(.system(size: 14))
                        Text(animal.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 12)

                Spacer()
            }

            // Bottom action bar
            VStack {
                Spacer()

                HStack(spacing: 20) {
                    // Retake button
                    Button(action: onDismiss) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Retake")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                        }
                    }

                    // Save button
                    Button(action: saveToPhotos) {
                        HStack(spacing: 8) {
                            ZStack {
                                Image(systemName: "square.and.arrow.down")
                                    .opacity(showSavedConfirmation ? 0 : 1)
                                    .scaleEffect(showSavedConfirmation ? 0.8 : 1)

                                Image(systemName: "checkmark")
                                    .opacity(showSavedConfirmation ? 1 : 0)
                                    .scaleEffect(showSavedConfirmation ? 1 : 0.8)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 16, height: 16)
                            Text(showSavedConfirmation ? "Saved!" : "Save")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(.white)
                                .shadow(color: .white.opacity(0.3), radius: 16, x: 0, y: 2)
                        }
                        .scaleEffect(saveScale)
                        .animation(.easeInOut(duration: 0.2), value: showSavedConfirmation)
                    }
                    .disabled(showSavedConfirmation)
                }
                .padding(.bottom, 40)
                .offset(y: appearAnimation ? 0 : 80)
                .opacity(appearAnimation ? 1 : 0)
            }

            // Saved confirmation overlay
            if showSavedConfirmation {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                        Text("Photo saved to library")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
    }

    private func saveToPhotos() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Button bounce
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            saveScale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                saveScale = 1.0
            }
        }

        // Save using PHPhotoLibrary (handles permissions properly)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: self.image.jpegData(compressionQuality: 0.95)!, options: nil)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showSavedConfirmation = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showSavedConfirmation = false
                            }
                        }
                    }
                }
            }
        }
    }
}
