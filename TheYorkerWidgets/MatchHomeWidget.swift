//
//  MatchHomeWidget.swift
//  TheYorkerWidgets
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import WidgetKit
import SwiftUI

// These duplicate Extensions.swift because widget extensions are separate compilation units.
// MARK: - Widget-local design tokens

private extension Color {
    /// Cricket green — #00D084
    static let wAccent   = Color(red: 0/255,   green: 208/255, blue: 132/255)
    /// Live red — #FF3B5C
    static let wLive     = Color(red: 255/255,  green: 59/255,  blue: 92/255)
    /// Deep navy — #070C18
    static let wBG       = Color(red: 7/255,    green: 12/255,  blue: 24/255)
    /// Card navy — #0D1526
    static let wCard     = Color(red: 13/255,   green: 21/255,  blue: 38/255)
    /// Secondary text — #6B7A99
    static let wTextSec  = Color(red: 107/255,  green: 122/255, blue: 153/255)
    /// Tertiary text — #374869
    static let wTextTert = Color(red: 55/255,   green: 72/255,  blue: 105/255)
    /// Divider — #1C2E4A
    static let wDivider  = Color(red: 28/255,   green: 46/255,  blue: 74/255)
}

// MARK: - Timeline Entry

/// The single data snapshot the widget renders at a given point in time.
struct MatchWidgetEntry: TimelineEntry {
    let date: Date          // required by `TimelineEntry`
    let matches: [WidgetMatch]
    let isMock: Bool        // used to show a "Demo" indicator in development
}

/// Lightweight match model for widgets — only the fields the UI needs.
/// A separate struct avoids importing the full `Match` model (which requires `Foundation`
/// decoders and app-only code) into the widget extension.
struct WidgetMatch: Identifiable {
    let id: String
    let team1: String
    let team2: String
    let team1Short: String
    let team2Short: String
    let score1: String
    let score2: String
    let status: String
    let matchType: String
    let isLive: Bool
}

// MARK: - Mock Data

extension WidgetMatch {
    /// Live match fixture — used for previews, placeholders, and when the API key is absent.
    static let mockLive = WidgetMatch(
        id: "mock_1",
        team1: "India", team2: "Australia",
        team1Short: "IND", team2Short: "AUS",
        score1: "198/3", score2: "Yet to bat",
        status: "India are batting",
        matchType: "ODI", isLive: true
    )
    static let mockUpcoming = WidgetMatch(
        id: "mock_2",
        team1: "Pakistan", team2: "South Africa",
        team1Short: "PAK", team2Short: "SA",
        score1: "—", score2: "—",
        status: "Tomorrow, 14:30",
        matchType: "T20", isLive: false
    )
    static let mockRecent = WidgetMatch(
        id: "mock_3",
        team1: "England", team2: "New Zealand",
        team1Short: "ENG", team2Short: "NZ",
        score1: "310/10", score2: "289/10",
        status: "NZ won by 4 wkts",
        matchType: "TEST", isLive: false
    )
}

// MARK: - Timeline Provider

/// Drives the widget's data lifecycle.
///
/// The refresh interval is adaptive: 60 s when any match is live, 5 min otherwise —
/// balancing score freshness against battery/network cost.
struct MatchWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> MatchWidgetEntry {
        // Placeholder is shown while the widget loads for the first time
        MatchWidgetEntry(date: .now, matches: [.mockLive, .mockUpcoming, .mockRecent], isMock: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (MatchWidgetEntry) -> Void) {
        // Snapshot is used in the widget gallery — always return mock data instantly
        completion(MatchWidgetEntry(date: .now, matches: [.mockLive, .mockUpcoming, .mockRecent], isMock: true))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MatchWidgetEntry>) -> Void) {
        // Read mock toggle from the App Group suite (shared with the main app)
        let useMock = UserDefaults(suiteName: "group.com.vishal.TheYorker")?.bool(forKey: "useMockData") ?? true

        if useMock {
            let entry = MatchWidgetEntry(date: .now, matches: [.mockLive, .mockUpcoming, .mockRecent], isMock: true)
            // Refresh every 5 min even in mock mode so the widget timeline doesn't go stale
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300))))
            return
        }

        Task {
            let matches = await fetchMatches()
            let entry = MatchWidgetEntry(date: .now, matches: matches, isMock: false)
            // Refresh more aggressively (1 min) when there's a live match in progress
            let refresh = Date.now.addingTimeInterval(matches.contains(where: { $0.isLive }) ? 60 : 300)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    /// Fetches up to 3 matches from CricAPI using the key stored in the App Group.
    /// Falls back to mock data on any network or decoding failure.
    private func fetchMatches() async -> [WidgetMatch] {
        guard let apiKey = UserDefaults(suiteName: "group.com.vishal.TheYorker")?.string(forKey: "cricAPIKey"),
              !apiKey.isEmpty,
              let url = URL(string: "https://api.cricapi.com/v1/currentMatches?apikey=\(apiKey)&offset=0")
        else { return [.mockLive, .mockUpcoming, .mockRecent] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            // Inline minimal response model — avoids importing the main app's `Match` type
            struct Resp: Decodable {
                struct Item: Decodable {
                    var id: String; var name: String
                    var teams: [String]?; var matchType: String?
                    var status: String?; var score: [ScoreItem]?
                    struct ScoreItem: Decodable {
                        var r: Int?; var w: Int?; var inning: String?
                    }
                }
                var data: [Item]?
            }

            let resp = try JSONDecoder().decode(Resp.self, from: data)
            return (resp.data ?? []).prefix(3).compactMap { item -> WidgetMatch? in
                guard let t = item.teams, t.count >= 2 else { return nil }
                let t1 = t[0]; let t2 = t[1]
                func short(_ s: String) -> String { String(s.prefix(3)).uppercased() }
                func score(_ team: String) -> String {
                    guard let s = item.score?.first(where: { $0.inning?.contains(team) == true }),
                          let r = s.r, let w = s.w else { return "—" }
                    return "\(r)/\(w)"
                }
                // Treat as live when there is score data and the match hasn't been decided
                let st = item.status?.lowercased() ?? ""
                let isLive = !st.contains("won") && !st.contains("yet to") && item.score?.isEmpty == false
                return WidgetMatch(
                    id: item.id, team1: t1, team2: t2,
                    team1Short: short(t1), team2Short: short(t2),
                    score1: score(t1), score2: score(t2),
                    status: item.status ?? "", matchType: item.matchType?.uppercased() ?? "MATCH",
                    isLive: isLive
                )
            }
        } catch {
            return [.mockLive, .mockUpcoming, .mockRecent]
        }
    }
}

// MARK: - Widget

/// Declares the home-screen widget and registers it with WidgetKit.
///
/// The gradient is passed directly to `.containerBackground(for: .widget)` — the iOS 17+
/// recommended pattern. This lets the system apply its own container shape (corner radius,
/// padding, shadow) correctly and avoids double-clipping with an internal `clipShape`.
struct MatchHomeWidget: Widget {
    let kind = "MatchHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatchWidgetProvider()) { entry in
            MatchWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.wBG, Color.wCard],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("The Yorker")
        .description("Live cricket scores on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Root Widget View

/// Dispatches to `SmallWidgetView` or `MediumWidgetView` based on the widget family.
struct MatchWidgetView: View {
    let entry: MatchWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(match: entry.matches.first ?? .mockLive)
        case .systemMedium: MediumWidgetView(entry: entry)
        default:            SmallWidgetView(match: entry.matches.first ?? .mockLive)
        }
    }
}

// MARK: - Small Widget

/// Single-match compact widget — flag, abbreviation, score, status.
///
/// The gradient background lives in `MatchHomeWidget.containerBackground` — this view
/// only draws the foreground content (+ optional live glow overlay).
struct SmallWidgetView: View {
    let match: WidgetMatch

    var body: some View {
        ZStack {
            // Subtle top-right glow overlay during live matches (no base gradient here —
            // it's provided by `containerBackground` in `MatchHomeWidget`).
            if match.isLive {
                RadialGradient(
                    colors: [Color.wAccent.opacity(0.14), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 150
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                // Header row: format badge + live dot
                HStack {
                    typeBadge(match.matchType)
                    Spacer()
                    if match.isLive { liveDot }
                }

                Spacer()

                // Team rows with scores
                teamRow(flag: flag(match.team1), short: match.team1Short, score: match.score1)
                Spacer().frame(height: 7)
                teamRow(flag: flag(match.team2), short: match.team2Short, score: match.score2)

                Spacer()

                // Thin divider before status
                Rectangle()
                    .fill(Color.wDivider)
                    .frame(height: 1)
                    .padding(.bottom, 5)

                // Match status line
                Text(match.status)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(match.isLive ? Color.wAccent : Color.wTextSec)
                    .lineLimit(1)
            }
            .padding(12)
        }
        // No clipShape — system clips to its own container shape (ContainerRelativeShape)
    }

    private func teamRow(flag f: String, short: String, score: String) -> some View {
        HStack(spacing: 6) {
            Text(f).font(.system(size: 19))
            Text(short)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color.wTextSec)
            Spacer()
            Text(score)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Medium Widget

/// Two-column medium widget: primary match on the left, up to two secondary matches on the right.
///
/// Base gradient background is in `MatchHomeWidget.containerBackground`. This view draws
/// the two-column layout and the optional live glow overlay only.
struct MediumWidgetView: View {
    let entry: MatchWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left panel — featured (first) match
            if let primary = entry.matches.first {
                primaryPanel(primary)
            }

            // Gradient vertical divider — fades at top and bottom for a softer edge
            LinearGradient(
                colors: [Color.wDivider.opacity(0.3),
                         Color.wDivider.opacity(0.7),
                         Color.wDivider.opacity(0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 1)
            .padding(.vertical, 14)

            // Right panel — secondary matches (2nd and 3rd)
            VStack(spacing: 0) {
                let secondary = Array(entry.matches.dropFirst().prefix(2))
                if secondary.isEmpty {
                    Spacer()
                    Text("No more matches")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.wTextTert)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    ForEach(Array(secondary.enumerated()), id: \.element.id) { idx, match in
                        miniRow(match)
                        // Only draw a divider between rows, not after the last one
                        if idx < secondary.count - 1 {
                            Rectangle()
                                .fill(Color.wDivider.opacity(0.5))
                                .frame(height: 1)
                                .padding(.horizontal, 12)
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // No clipShape — system clips to its own container shape (ContainerRelativeShape)
    }

    private func primaryPanel(_ match: WidgetMatch) -> some View {
        ZStack {
            // Green glow overlay when match is live
            if match.isLive {
                RadialGradient(
                    colors: [Color.wAccent.opacity(0.12), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 180
                )
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    typeBadge(match.matchType)
                    Spacer()
                    if match.isLive { liveDot }
                }

                Spacer()

                teamRowLarge(flag: flag(match.team1), short: match.team1Short, score: match.score1)
                Spacer().frame(height: 8)
                teamRowLarge(flag: flag(match.team2), short: match.team2Short, score: match.score2)

                Spacer()

                Rectangle().fill(Color.wDivider).frame(height: 1).padding(.bottom, 5)

                Text(match.status)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(match.isLive ? Color.wAccent : Color.wTextSec)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Compact row shown in the right column of the medium widget.
    private func miniRow(_ match: WidgetMatch) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Badge row: format type + live dot + status
            HStack(spacing: 5) {
                Text(match.matchType)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(Color.wAccent)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.wAccent.opacity(0.12))
                    .clipShape(Capsule())
                if match.isLive {
                    Circle().fill(Color.wLive).frame(width: 5, height: 5)
                }
                Spacer()
                Text(match.status)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(match.isLive ? Color.wAccent : Color.wTextTert)
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .trailing)
            }

            // Team 1 row
            HStack(spacing: 4) {
                Text(flag(match.team1)).font(.system(size: 11))
                Text(match.team1Short)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(match.score1)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            // Team 2 row — score greyed out when yet to bat
            HStack(spacing: 4) {
                Text(flag(match.team2)).font(.system(size: 11))
                Text(match.team2Short)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.wTextSec)
                Spacer()
                Text(match.score2 == "Yet to bat" ? "—" : match.score2)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Color.wTextSec)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func teamRowLarge(flag f: String, short: String, score: String) -> some View {
        HStack(spacing: 6) {
            Text(f).font(.system(size: 18))
            Text(short)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color.wTextSec)
            Spacer()
            Text(score)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Shared Widget Helpers

/// Resolves the emoji flag from `MatchActivityAttributes` (shared with the Live Activity).
private func flag(_ team: String) -> String {
    MatchActivityAttributes.flag(for: team)
}

/// Format-type badge pill — consistent styling across small and medium widgets.
private func typeBadge(_ type: String) -> some View {
    Text(type)
        .font(.system(size: 9, weight: .black, design: .rounded))
        .foregroundColor(Color.wAccent)
        .kerning(0.3)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.wAccent.opacity(0.13))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.wAccent.opacity(0.25), lineWidth: 0.7))
}

/// Minimal live indicator — static dot + "LIVE" label (no animation in widgets per system policy).
private var liveDot: some View {
    HStack(spacing: 3) {
        Circle()
            .fill(Color.wLive)
            .frame(width: 5, height: 5)
        Text("LIVE")
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundColor(Color.wLive)
    }
}
