//
//  OtherEyesApp.swift
//  OtherEyes
//
//  Created by Kezia Meilany Tandapai on 14/03/26.
//

import SwiftUI

@main
struct OtherEyesApp: App {
    init() {
        // Clear visited animals so the app resets its memory when completely destroyed/restarted
        UserDefaults.standard.removeObject(forKey: "visitedAnimals")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
