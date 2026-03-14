//
//  AnimalModel.swift
//  OtherEyes
//

import Foundation

enum Animal: String, CaseIterable, Identifiable, Hashable {
    case dog, cat, fly, bird, snake, mantisShrimp

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dog:          return "Dog"
        case .cat:          return "Cat"
        case .fly:          return "Fly"
        case .bird:         return "Bird"
        case .snake:        return "Snake"
        case .mantisShrimp: return "Mantis Shrimp"
        }
    }

    var emoji: String {
        switch self {
        case .dog:          return "🐶"
        case .cat:          return "🐱"
        case .fly:          return "🪰"
        case .bird:         return "🦅"
        case .snake:        return "🐍"
        case .mantisShrimp: return "🦐"
        }
    }

    var description: String {
        switch self {
        case .dog:          return "Dichromatic vision"
        case .cat:          return "Night-adapted eyes"
        case .fly:          return "Compound mosaic vision"
        case .bird:         return "340° wide-angle vision"
        case .snake:        return "Thermal infrared sensing"
        case .mantisShrimp: return "12-16 color receptors"
        }
    }

    var funFact: String {
        switch self {
        case .dog:
            return "Dogs see fewer colors than humans, but they are much better at detecting motion — which helped their ancestors track moving prey across open plains."
        case .cat:
            return "Cats can see in light levels about six times lower than humans, thanks to a reflective layer behind their retinas called the tapetum lucidum."
        case .fly:
            return "Flies see the world almost in slow motion compared to humans — they can detect motion at up to 250 frames per second, helping them escape predators instantly."
        case .bird:
            return "Most birds have a field of view up to 340°, letting them see almost all the way behind them. They also have four types of color receptors — including one for ultraviolet light — giving them far richer color vision than humans."
        case .snake:
            return "Pit vipers can detect heat from warm-blooded prey using infrared-sensitive pit organs. In this simulation, darker areas appear warmer — just as a snake might sense a hidden animal against a cool background."
        case .mantisShrimp:
            return "Mantis shrimp have 12-16 types of color receptors — compared to just 3 in humans. They can see ultraviolet and polarized light that humans cannot even imagine."
        }
    }

    var cardGradientColors: [String] {
        switch self {
        case .dog:          return ["#B8D4F0", "#E8F4FD"]
        case .cat:          return ["#C8B8F0", "#EDE8FD"]
        case .fly:          return ["#B8E8C8", "#E8FDF0"]
        case .bird:         return ["#F0D8B8", "#FDF5E8"]
        case .snake:        return ["#F0B8B8", "#FDE8E8"]
        case .mantisShrimp: return ["#F0B8E8", "#FDE8F8"]
        }
    }
}
