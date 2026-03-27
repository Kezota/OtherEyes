//
//  AnimalModel.swift
//  OtherEyes
//

import Foundation

enum Animal: String, CaseIterable, Identifiable, Hashable {
    case dog, cat, fly, cockroach, bird, fish, mantisShrimp, rat, eagle, ant, spider

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dog:          return "Dog"
        case .cat:          return "Cat"
        case .fly:          return "Fly"
        case .cockroach:    return "Cockroach"
        case .bird:         return "Bird"
        case .fish:         return "Fish"
        case .mantisShrimp: return "Mantis Shrimp"
        case .rat:          return "Rat"
        case .eagle:        return "Eagle"
        case .ant:          return "Ant"
        case .spider:       return "Spider"
        }
    }

    var emoji: String {
        switch self {
        case .dog:          return "🐶"
        case .cat:          return "🐱"
        case .fly:          return "🪰"
        case .cockroach:    return "🪳"
        case .bird:         return "🐦"
        case .fish:         return "🐟"
        case .mantisShrimp: return "🦐"
        case .rat:          return "🐀"
        case .eagle:        return "🦅"
        case .ant:          return "🐜"
        case .spider:       return "🕷️"
        }
    }

    var description: String {
        switch self {
        case .dog:          return "Dichromatic vision"
        case .cat:          return "Night-adapted eyes"
        case .fly:          return "Compound mosaic vision"
        case .cockroach:    return "Blurry, motion-sensitive eyes"
        case .bird:         return "340° wide-angle vision"
        case .fish:         return "Wide-angle underwater"
        case .mantisShrimp: return "12-16 color receptors"
        case .rat:          return "Blurry, dim, greenish vision"
        case .eagle:        return "Hyper-focuse telescopic"
        case .ant:          return "Macro ground-level vision"
        case .spider:       return "Fragmented, motion-sensitive"
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
        case .cockroach:
            return "Cockroaches can react in less than 50 milliseconds. They sense tiny changes in light and movement, which is why they disappear instantly."
        case .bird:
            return "Many birds can see up to 340° around them and can detect ultraviolet light that humans cannot see."
        case .fish:
            return "Some fish can see nearly 360° around them, allowing them to detect movement from almost every direction."
        case .mantisShrimp:
            return "Mantis shrimp have up to 16 types of color receptors, while humans only have 3. They can detect light that we cannot even see."
        case .rat:
            return "Rats have very blurry vision, but they can detect even small movements in low light and rely more on their other senses to navigate."
        case .eagle:
            return "Eagles can spot a rabbit from over 3 km away. Their eyes have around 1 million photoreceptors per mm², giving them 4–8× sharper vision than humans."
        case .ant:
            return "Most ants have very poor vision and can only see a few centimeters ahead. They navigate primarily using chemical trails and touch rather than sight."
        case .spider:
            return "Most spiders have 8 eyes arranged in different pairs. While their main pair sees sharp details, the secondary eyes are specialized for detecting motion and light changes."
        }
    }

    var cardGradientColors: [String] {
        switch self {
        case .dog:          return ["#B8D4F0", "#E8F4FD"]
        case .cat:          return ["#C8B8F0", "#EDE8FD"]
        case .fly:          return ["#B8E8C8", "#E8FDF0"]
        case .cockroach:    return ["#D4C8A8", "#F5F0DC"]
        case .bird:         return ["#F0D8B8", "#FDF5E8"]
        case .fish:         return ["#A8D4E8", "#DCF0F8"]
        case .mantisShrimp: return ["#F0B8E8", "#FDE8F8"]
        case .rat:          return ["#B8D4B8", "#E0EDD8"]
        case .eagle:        return ["#E8D4A8", "#FDF5DC"]  // warm golden
        case .ant:          return ["#C8A888", "#E8DCC8"]  // earthy brown
        case .spider:       return ["#D8B8E8", "#F5E8FD"]  // muted purple
        }
    }

    /// Short instruction to help the user get the most immersive experience.
    var immersionTip: String {
        switch self {
        case .dog:          return "Move slowly — dogs track motion, not detail"
        case .cat:          return "Try a dim room for the full night-vision effect"
        case .fly:          return "Wave your hand — notice the slow-motion trails"
        case .cockroach:    return "Point at a light, then look away quickly"
        case .bird:         return "Look around — you have almost 360° vision"
        case .fish:         return "Move the phone gently, like drifting underwater"
        case .mantisShrimp: return "Look at colorful objects — you see beyond human colors"
        case .rat:          return "Move objects in frame — motion is all you see"
        case .eagle:        return "Point at something far away — focus locks on center"
        case .ant:          return "Place your phone near the ground and look around"
        case .spider:       return "Watch moving objects pop out across your fragmented vision"
        }
    }
}
