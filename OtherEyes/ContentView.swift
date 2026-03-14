//
//  ContentView.swift
//  OtherEyes
//
//  Created by Kezia Meilany Tandapai on 14/03/26.
//

import SwiftUI

struct ContentView: View {
    let animals = Animal.sampleAnimals

    var columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 16), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(colors: [Color(.systemBackground), Color(.init(red: 0.94, green: 0.97, blue: 1.0))], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("OtherEyes")
                            .font(.largeTitle).fontWeight(.semibold)
                        Text("See the world through different creatures")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(animals) { animal in
                                NavigationLink(value: animal) {
                                    AnimalCard(animal: animal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
                .padding(.top)
                .navigationDestination(for: Animal.self) { animal in
                    VisionView(selectedAnimal: animal)
                }
            }
        }
    }
}

struct AnimalCard: View {
    let animal: Animal

    var body: some View {
        ZStack {
            // Glass card background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.35))
                        .blur(radius: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.6), lineWidth: 0.6)
                )

            VStack(spacing: 8) {
                Text(animal.emoji)
                    .font(.system(size: 40))
                Text(animal.name)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding()
        }
        .frame(height: 140)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)
    }
}

#Preview {
    ContentView()
}
