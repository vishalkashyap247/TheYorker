//
//  TheYorkerApp.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import SwiftUI

// MARK: - App Entry Point

/// Root `App` struct. Uses `@main` so the OS calls `body` to build the scene graph.
@main
struct TheYorkerApp: App {
    init() {
        // Tint navigation back-button and bar items globally with the app's accent green.
        // Using UIAppearance here ensures the colour is applied before any view renders.
        UINavigationBar.appearance().tintColor = UIColor(Color.yorkerAccent)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Lock the app to dark mode — the colour tokens are tuned for dark backgrounds only.
                .preferredColorScheme(.dark)
        }
    }
}
