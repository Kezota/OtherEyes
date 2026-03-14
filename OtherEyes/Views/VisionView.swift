import SwiftUI
import UIKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct VisionView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var camera = CameraSession()
    @State var selectedAnimal: Animal

    // comparison slider (0 = full animal, 1 = full human)
    @State private var comparison: CGFloat = 0.0
    @State private var showInsight: Bool = false

    private let ciContext = CIContext()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color(.systemBackground), Color(.init(red: 0.94, green: 0.97, blue: 1.0))], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                ZStack {
                    // Live camera full view (human)
                    CameraPreview(camera: camera)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.6), lineWidth: 0.6)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)

                    // Animal filtered overlay that is masked by comparison slider
                    CameraPreview(camera: camera)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.6), lineWidth: 0.6)
                        )
                        .modifier(AnimalFilterModifier(type: selectedAnimal.type))
                        .mask(
                            GeometryReader { geo in
                                Rectangle()
                                    .frame(width: geo.size.width * (1.0 - comparison))
                                    .offset(x: -(geo.size.width * (comparison - 0.5)))
                            }
                        )

                    // Vertical slider on the right
                    HStack {
                        Spacer()
                        VStack {
                            Spacer()
                            VerticalGlassSlider(value: $comparison)
                                .frame(width: 44, height: 240)
                                .padding(.trailing, 8)
                            Spacer()
                        }
                    }
                    .padding(.vertical)

                    // Insight popup
                    if showInsight {
                        InsightPopup(text: selectedAnimal.funFact) {
                            withAnimation { showInsight = false }
                        }
                        .frame(maxWidth: 320)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                    }
                }
                .padding()
                .frame(maxHeight: .infinity)

                bottomBar
                    .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            // Stop camera when leaving
        }
        .onAppear {
            // nothing extra for now
        }
    }

    var topBar: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            Spacer()

            Text(selectedAnimal.name)
                .font(.headline)

            Spacer()

            Button(action: { withAnimation { showInsight.toggle() } }) {
                Image(systemName: "lightbulb")
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    var bottomBar: some View {
        HStack(spacing: 16) {
            ForEach(Animal.sampleAnimals) { animal in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedAnimal = animal
                    }
                }) {
                    Text(animal.emoji)
                        .font(.system(size: 28))
                        .padding(10)
                        .background(selectedAnimal.id == animal.id ? Color.white.opacity(0.4) : Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.6), lineWidth: 0.6))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)
    }
}

// MARK: - Insight Popup
struct InsightPopup: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                Text("Did you know?")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.6), lineWidth: 0.6))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)
        .padding(.top, 40)
        .onTapGesture { /* consume */ }
        .onTapOutside { onClose() }
    }
}

// MARK: - Vertical Glass Slider
struct VerticalGlassSlider: View {
    @Binding var value: CGFloat // 0..1
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.6), lineWidth: 0.6))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)

                // track and arrows
                VStack {
                    Spacer()
                    Image(systemName: "chevron.left")
                        .rotationEffect(.degrees(-90))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)
                    Spacer()
                }

                // handle
                let handleY = (1.0 - value) * geo.size.height

                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .shadow(radius: 4)
                    .offset(x: 0, y: handleY - geo.size.height / 2)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation
                            }
                            .onChanged { g in
                                let pos = max(0, min(1, 1.0 - (g.location.y / geo.size.height)))
                                self.value = pos
                            }
                    )
            }
        }
    }
}

// MARK: - Animal Filter Modifier
struct AnimalFilterModifier: ViewModifier {
    let type: AnimalType

    func body(content: Content) -> some View {
        switch type {
        case .dog:
            content
                .colorMultiply(Color.yellow)
                .saturation(0.6)
        case .cat:
            content
                .brightness(0.05)
                .saturation(0.6)
                .blur(radius: 0.6)
        case .fly:
            content
                .overlay(CompoundEyeOverlay().blendMode(.overlay))
        case .bird:
            content
                .contrast(1.2)
                .scaleEffect(1.03)
        case .snake:
            content
                .colorMultiply(Color.orange)
                .saturation(0.3)
                .blendMode(.screen)
        case .mantisShrimp:
            content
                .hueRotation(.degrees(35))
                .saturation(1.6)
        }
    }
}

// very simple compound eye overlay to simulate a mosaic
struct CompoundEyeOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let size = max(8, min(24, geo.size.width / 30))
            Path { path in
                // no path; we'll tile circles instead
            }
            .overlay(
                ForEach(0..<Int(geo.size.width / size) * Int(geo.size.height / size), id: \.self) { _ in
                    Circle()
                        .stroke(Color.white.opacity(0.02), lineWidth: 0.5)
                        .background(Circle().fill(Color.white.opacity(0.01)))
                }
            )
            .clipped()
        }
    }
}

// MARK: - Helpers
// onTapOutside - simple iOS16+ modifier
extension View {
    @ViewBuilder
    func onTapOutside(perform action: @escaping () -> Void) -> some View {
        if #available(iOS 16.4, *) {
            self.onTapGesture { }
                .background(BackgroundTapView(action: action))
        } else {
            self
        }
    }
}

@available(iOS 16.4, *)
struct BackgroundTapView: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}
