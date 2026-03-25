//
//  AnimalModel.swift
//  OtherEyes
//

import Foundation

enum Animal: String, CaseIterable, Identifiable, Hashable {
    case dog, cat, fly, bird, cockroach, fish, mantisShrimp, rat

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dog:          return "Dog"
        case .cat:          return "Cat"
        case .fly:          return "Fly"
        case .bird:         return "Bird"
        case .cockroach:    return "Cockroach"
        case .fish:         return "Fish"
        case .mantisShrimp: return "Mantis Shrimp"
        case .rat:          return "Rat"
        }
    }

    var emoji: String {
        switch self {
        case .dog:          return "🐶"
        case .cat:          return "🐱"
        case .fly:          return "🪰"
        case .bird:         return "🐦"
        case .cockroach:    return "🪳"
        case .fish:         return "🐟"
        case .mantisShrimp: return "🦐"
        case .rat:          return "🐀"
        }
    }

    var description: String {
        switch self {
        case .dog:          return "Dichromatic vision"
        case .cat:          return "Night-adapted eyes"
        case .fly:          return "Compound mosaic vision"
        case .bird:         return "340° wide-angle vision"
        case .cockroach:    return "Blurry, motion-sensitive eyes"
        case .fish:         return "Wide-angle underwater vision"
        case .mantisShrimp: return "12-16 color receptors"
        case .rat:          return "Blurry, dim, greenish vision"
        }
    }

    var funFact: String {
        switch self {
        case .dog:
            return "Dogs don't see the full range of colors like humans. Reds and greens fade into dull tones, but they are far better at detecting movement."
        case .cat:
            return "Cats can see in light levels about 6 times lower than humans, so what looks completely dark to you is still visible to them."
        case .fly:
            return "Flies see the world in slow motion. They can detect motion up to 250 frames per second, which makes your movements look much slower."
        case .bird:
            return "Many birds can see up to 340° around them and can detect ultraviolet light that humans cannot see."
        case .cockroach:
            return "Cockroaches can react in less than 50 milliseconds. They sense tiny changes in light and movement, which is why they disappear instantly."
        case .fish:
            return "Some fish can see nearly 360° around them, allowing them to detect movement from almost every direction."
        case .mantisShrimp:
            return "Mantis shrimp have up to 16 types of color receptors, while humans only have 3. They can detect light that we cannot even see."
        case .rat:
            return "Rats have very blurry vision, but they can detect even small movements in low light and rely more on their other senses to navigate."
        }
    }

    var cardGradientColors: [String] {
        switch self {
        case .dog:          return ["#B8D4F0", "#E8F4FD"]
        case .cat:          return ["#C8B8F0", "#EDE8FD"]
        case .fly:          return ["#B8E8C8", "#E8FDF0"]
        case .bird:         return ["#F0D8B8", "#FDF5E8"]
        case .cockroach:    return ["#D4C8A8", "#F5F0DC"]
        case .fish:         return ["#A8D4E8", "#DCF0F8"]
        case .mantisShrimp: return ["#F0B8E8", "#FDE8F8"]
        case .rat:          return ["#B8D4B8", "#E0EDD8"]
        }
    }
}
