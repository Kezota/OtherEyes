import Foundation
import SwiftUI

enum AnimalType: String, Codable {
    case dog, cat, fly, bird, snake, mantisShrimp
}

struct Animal: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let emoji: String
    let type: AnimalType
    let funFact: String
}

extension Animal {
    static let sampleAnimals: [Animal] = [
        Animal(id: UUID(), name: "Dog", emoji: "🐶", type: .dog, funFact: "Dogs see the world mostly in blues and yellows and are excellent at detecting motion."),
        Animal(id: UUID(), name: "Cat", emoji: "🐱", type: .cat, funFact: "Cats have excellent night vision and see well in low light."),
        Animal(id: UUID(), name: "Fly", emoji: "🪰", type: .fly, funFact: "Flies have compound eyes that create a mosaic view and perceive motion very quickly."),
        Animal(id: UUID(), name: "Bird", emoji: "🦅", type: .bird, funFact: "Birds like eagles have extremely sharp vision and can see ultraviolet light."),
        Animal(id: UUID(), name: "Snake", emoji: "🐍", type: .snake, funFact: "Some snakes can sense infrared heat, allowing them to detect warm-blooded prey in the dark."),
        Animal(id: UUID(), name: "Mantis Shrimp", emoji: "🦐", type: .mantisShrimp, funFact: "Mantis shrimp have many photoreceptors and perceive colors humans can't imagine.")
    ]
}