//
//  MatchActivityAttributes.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//
//  IMPORTANT: This file must be added to BOTH the "TheYorker" app target AND the
//  "TheYorkerWidgets" extension target in Xcode. It is the shared contract between
//  the main app (which starts/updates activities) and the widget extension (which renders them).
//  Keeping one source file in both targets avoids drift between the two schemas.
//

import ActivityKit
import SwiftUI

// MARK: - Activity Attributes

/// Defines the static and dynamic data contract for a match Live Activity.
///
/// `ActivityAttributes` is the ActivityKit protocol that separates data into two buckets:
/// - Properties on the struct itself: set once when the activity starts, never updated.
/// - `ContentState`: updated as the match progresses via `Activity.update(_:)`.
struct MatchActivityAttributes: ActivityAttributes {

    // MARK: Static Data (set once when activity starts)

    var matchId:    String  // unique match identifier from CricAPI
    var matchName:  String  // e.g. "India vs Australia"
    var team1:      String  // full country name (used for flag lookup)
    var team2:      String
    var team1Short: String  // three-letter abbreviation e.g. "IND"
    var team2Short: String
    var matchType:  String  // "ODI" | "T20" | "TEST" | "IPL"
    var venue:      String

    // MARK: Dynamic State (updated as match progresses)

    public struct ContentState: Codable, Hashable {
        var team1Score:  String      // e.g. "198/3"
        var team2Score:  String      // e.g. "Yet to bat"
        var overs:       String      // e.g. "32.4"
        var runRate:     String      // e.g. "6.11"
        var status:      String      // e.g. "India are batting"
        var isLive:      Bool
        var lastUpdated: Date        // used to compute "2m ago" timestamps in the widget
    }
}

// MARK: - Mock Data

extension MatchActivityAttributes {

    /// Pre-built attributes for previewing the Live Activity without a real match.
    static var mockAttributes: MatchActivityAttributes {
        MatchActivityAttributes(
            matchId:    "mock_ind_aus_001",
            matchName:  "India vs Australia",
            team1:      "India",
            team2:      "Australia",
            team1Short: "IND",
            team2Short: "AUS",
            matchType:  "ODI",
            venue:      "Wankhede Stadium, Mumbai"
        )
    }

    /// Mid-innings state used alongside `mockAttributes` for UI previews.
    static var mockState: ContentState {
        ContentState(
            team1Score:  "198/3",
            team2Score:  "Yet to bat",
            overs:       "32.4",
            runRate:     "6.11",
            status:      "India are batting",
            isLive:      true,
            lastUpdated: .now
        )
    }
}

// MARK: - Helpers Shared Across Targets

extension MatchActivityAttributes {
    /// Returns the emoji flag for a team name — mirrors `String.teamFlag` from the main app.
    ///
    /// Duplicated here (rather than importing Extensions.swift) because the widget extension
    /// is a separate compilation unit and cannot import non-framework code from the main target.
    static func flag(for team: String) -> String {
        let map: [String: String] = [
            "India": "🇮🇳", "Australia": "🇦🇺", "England": "🏴󠁧󠁢󠁥󠁮󠁧󠁿",
            "Pakistan": "🇵🇰", "New Zealand": "🇳🇿", "South Africa": "🇿🇦",
            "West Indies": "🏝️", "Sri Lanka": "🇱🇰", "Bangladesh": "🇧🇩",
            "Afghanistan": "🇦🇫", "Ireland": "🇮🇪", "Zimbabwe": "🇿🇼"
        ]
        return map[team] ?? "🏏"
    }
}
