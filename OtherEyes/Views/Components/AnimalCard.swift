//
//  AnimalCard.swift
//  OtherEyes
//

import SwiftUI

struct AnimalCard: View {
    let animal: Animal

    var body: some View {
        VStack(spacing: 5) {
            Text(animal.emoji)
                .font(.system(size: 44))

            Text(animal.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))

            Text(animal.description)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
    }
}

#Preview {
    AnimalCard(animal: .dog)
        .frame(width: 160)
        .padding()
}
