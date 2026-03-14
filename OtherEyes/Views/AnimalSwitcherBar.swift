//
//  AnimalSwitcherBar.swift
//  OtherEyes
//

import SwiftUI

struct AnimalSwitcherBar: View {
    @Binding var selectedAnimal: Animal
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Animal.allCases) { animal in
                        AnimalSwitcherButton(
                            animal: animal,
                            isSelected: selectedAnimal == animal,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedAnimal = animal
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: -4)
        }
        .padding(.horizontal, 16)
    }
}

struct AnimalSwitcherButton: View {
    let animal: Animal
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(animal.emoji)
                    .font(.system(size: isSelected ? 28 : 22))
                    .scaleEffect(isSelected ? 1.0 : 0.9)
                
                if isSelected {
                    Text(animal.name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, isSelected ? 14 : 10)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.75, green: 0.75, blue: 1.0).opacity(0.5),
                                    Color(red: 0.85, green: 0.70, blue: 1.0).opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.6), lineWidth: 1)
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        AnimalSwitcherBar(selectedAnimal: .constant(.dog))
            .padding()
    }
}
