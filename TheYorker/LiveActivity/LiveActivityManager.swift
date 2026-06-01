//
//  LiveActivityManager.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import ActivityKit
import SwiftUI

// MARK: - LiveActivityError

/// Typed errors emitted by `LiveActivityManager.start()` so callers can surface
/// a meaningful message instead of silently failing.
enum LiveActivityError: LocalizedError {
    case activitiesDisabled
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .activitiesDisabled:
            return "Live Activities are turned off.\n\nGo to Settings → TheYorker → Live Activities and enable them, then try again."
        case .requestFailed(let msg):
            return "Couldn't start the Live Activity: \(msg)"
        }
    }
}

// MARK: - LiveActivityManager

/// Singleton that owns the lifecycle of all running `Activity<MatchActivityAttributes>` instances.
///
/// Annotated `@Observable` (Swift Observation, iOS 17+) so any view that reads
/// `runningMatchIds` or calls `isTracking(_:)` will automatically re-render when the
/// set of active activities changes — without needing `@Published` or Combine publishers.
///
/// `@MainActor` guarantees all property mutations happen on the main thread, which means
/// there is no need for `.receive(on: DispatchQueue.main)` or `DispatchQueue.main.async`
/// around UI-triggering state writes. ActivityKit itself accepts updates from any thread,
/// but the Observable bookkeeping (`activities` dictionary) must only be touched here.
@MainActor
@Observable
final class LiveActivityManager {

    static let shared = LiveActivityManager()
    private init() {}

    // MARK: - State

    /// Internal mapping of matchId → running Activity object.
    /// The dictionary is the source of truth for which matches are currently tracked.
    private var activities: [String: Activity<MatchActivityAttributes>] = [:]

    /// Public read-only view of currently tracked match IDs, used by `LiveMatchCard`
    /// to show the correct "Track / Stop" button state.
    var runningMatchIds: Set<String> { Set(activities.keys) }

    /// Returns `true` when a Live Activity is running for the given match ID.
    func isTracking(_ matchId: String) -> Bool {
        activities[matchId] != nil
    }

    // MARK: - Start

    /// Starts a new Live Activity for the given match.
    ///
    /// - Parameters:
    ///   - match: The match to track.
    ///   - useMock: When `true`, uses pre-built mock attributes/state instead of live data.
    ///
    /// Throws `LiveActivityError.activitiesDisabled` when the user (or OS) has turned off
    /// Live Activities for this app — the caller should surface that to the user rather than
    /// silently ignoring it.
    ///
    /// If an activity already exists for this match it is ended first (awaited) to avoid
    /// duplicate-activity errors from ActivityKit.
    /// A stale date of +5 minutes tells the system the content may become outdated after that window.
    func start(match: Match, useMock: Bool) async throws {
        let info = ActivityAuthorizationInfo()
        print("[LiveActivity] areActivitiesEnabled = \(info.areActivitiesEnabled)")
        guard info.areActivitiesEnabled else {
            throw LiveActivityError.activitiesDisabled
        }

        let attrs: MatchActivityAttributes
        let state: MatchActivityAttributes.ContentState

        if useMock {
            attrs = .mockAttributes
            state = MatchActivityAttributes.mockState
        } else {
            attrs = MatchActivityAttributes(
                matchId:    match.id,
                matchName:  match.name,
                team1:      match.team1,
                team2:      match.team2,
                team1Short: match.team1.teamShort,
                team2Short: match.team2.teamShort,
                matchType:  match.matchTypeLabel,
                venue:      match.venue ?? ""
            )
            state = MatchActivityAttributes.ContentState(
                team1Score:  match.team1Scores.last?.shortFormatted ?? "—",
                team2Score:  match.team2Scores.last?.shortFormatted ?? "Yet to bat",
                overs:       match.team1Scores.last?.o.map { String(format: "%.1f", $0) } ?? "0.0",
                runRate:     {
                    // Compute run rate only when both runs and overs are available
                    if let s = match.team1Scores.last, let r = s.r, let o = s.o, o > 0 {
                        return String(format: "%.2f", Double(r) / o)
                    }
                    return "0.00"
                }(),
                status:      match.status ?? "Live",
                isLive:      match.isLive,
                lastUpdated: .now
            )
        }

        let id = attrs.matchId
        // Await the end so ActivityKit doesn't see two activities for the same match in flight
        await endActivity(matchId: id)

        do {
            let activity = try Activity<MatchActivityAttributes>.request(
                attributes: attrs,
                content: .init(state: state, staleDate: Date.now.addingTimeInterval(300)),
                pushType: nil  // push-token updates not yet implemented; polling is handled by the app
            )
            activities[id] = activity
            print("[LiveActivity] Started successfully, id = \(activity.id)")
        } catch {
            print("[LiveActivity] request() failed: \(error)")
            throw LiveActivityError.requestFailed(error.localizedDescription)
        }
    }

    // MARK: - Update

    /// Pushes a fresh `ContentState` to an already-running activity.
    /// Silently no-ops if no activity exists for `matchId`.
    func update(matchId: String, with match: Match) async {
        guard let activity = activities[matchId] else { return }
        let state = MatchActivityAttributes.ContentState(
            team1Score:  match.team1Scores.last?.shortFormatted ?? "—",
            team2Score:  match.team2Scores.last?.shortFormatted ?? "Yet to bat",
            overs:       match.team1Scores.last?.o.map { String(format: "%.1f", $0) } ?? "0.0",
            runRate:     {
                if let s = match.team1Scores.last, let r = s.r, let o = s.o, o > 0 {
                    return String(format: "%.2f", Double(r) / o)
                }
                return "0.00"
            }(),
            status:      match.status ?? "Live",
            isLive:      match.isLive,
            lastUpdated: .now
        )
        await activity.update(.init(state: state, staleDate: Date.now.addingTimeInterval(300)))
    }

    // MARK: - End

    /// Ends the Live Activity for `match`.
    /// Also ends the mock activity (hard-coded ID) in case it was started from Settings.
    func end(match: Match) {
        Task { await endActivity(matchId: match.id) }
        Task { await endActivity(matchId: "mock_ind_aus_001") } // also kill mock if running
    }

    /// Ends only the mock activity — used by the Settings "Preview" toggle.
    func endMock() {
        Task { await endActivity(matchId: "mock_ind_aus_001") }
    }

    private func endActivity(matchId: String) async {
        guard let activity = activities[matchId] else { return }
        await activity.end(.none, dismissalPolicy: .immediate)
        activities.removeValue(forKey: matchId)
    }

    /// Ends all running activities — useful for a reset or on sign-out.
    func endAll() async {
        for activity in Activity<MatchActivityAttributes>.activities {
            await activity.end(.none, dismissalPolicy: .immediate)
        }
        activities.removeAll()
    }
}
