//
//  Config.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import Foundation

// MARK: - API Configuration

/// Central configuration for the CricAPI integration.
/// Get your free API key at https://cricapi.com (100 req/day on the free tier).
enum APIConfig {
    // MARK: - Credentials

    /// Paste your CricAPI key here.
    /// Set `useMockData = false` once the key is in place.
    static let apiKey = "YOUR_CRICAPI_KEY_HERE"

    /// Root URL for all CricAPI v1 endpoints.
    static let baseURL = "https://api.cricapi.com/v1"

    // MARK: - Flags

    /// When true, all service calls return built-in mock fixtures instead of hitting the network.
    /// Flip to false once you have a real API key configured above.
    static let useMockData = true
}

// MARK: - App Group

/// The shared App Group suite used to pass settings between the main app and widget/Live Activity targets.
///
/// Both `MatchHomeWidget` and `LiveActivityManager` read `useMockData` and `cricAPIKey`
/// from this suite so the widget respects the same toggle the user sets in Settings.
///
/// To enable this in Xcode:
///   1. Select the TheYorker target → Signing & Capabilities → + Capability → App Groups
///   2. Add the group identifier below.
///   3. Repeat for the TheYorkerWidgets target.
enum AppGroup {
    static let suiteName = "group.com.vishal.TheYorker"
}
