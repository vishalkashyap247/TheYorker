//
//  MatchesViewModel.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import Foundation
import SwiftUI
import Observation

// MARK: - State Enum

/// Represents the four mutually exclusive loading states of any async data request.
/// Using an enum (rather than separate `isLoading`/`error` booleans) makes impossible
/// states unrepresentable and simplifies switch-exhaustive UI rendering.
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
}

// MARK: - MatchesViewModel

/// View model shared by `HomeView` and `ScheduleView`.
///
/// Marked `@Observable` (Swift Observation framework, iOS 17+) so SwiftUI automatically
/// re-renders only the views that actually read a changed property — no manual
/// `objectWillChange` calls needed.
@MainActor
@Observable
final class MatchesViewModel {

    var loadingState: LoadingState<[Match]> = .idle
    var searchText: String = ""
    var selectedFilter: MatchFilter = .all
    var isRefreshing: Bool = false

    private let service = CricAPIService.shared

    /// Full unfiltered match list exposed for the stats strip, which must always
    /// count across all matches regardless of the selected filter.
    private(set) var allMatches: [Match] = []

    // MARK: - Global Stats (independent of filter)

    /// Total number of matches currently in play across the full dataset.
    var totalLiveCount: Int     { allMatches.filter { $0.isLive }.count }

    /// Total matches that have not yet started (empty score, not live).
    var totalUpcomingCount: Int { allMatches.filter { ($0.score?.isEmpty ?? true) && !$0.isLive }.count }

    /// Total completed matches (status contains "won", "drawn", or "tied").
    var totalRecentCount: Int   {
        allMatches.filter {
            guard let s = $0.status?.lowercased() else { return false }
            return s.contains("won") || s.contains("drawn") || s.contains("tied")
        }.count
    }

    // MARK: - Filtered Results

    /// Applies the active `selectedFilter` and then the `searchText` predicate on top.
    /// Returns an empty array (rather than throwing) when no data has loaded yet.
    var filteredMatches: [Match] {
        let base: [Match]
        switch loadingState {
        case .loaded(let matches): base = matches
        default: return []
        }

        let filtered: [Match]
        switch selectedFilter {
        case .all:      filtered = base
        case .live:     filtered = base.filter { $0.isLive }
        case .upcoming: filtered = base.filter { ($0.score?.isEmpty ?? true) && !$0.isLive }
        case .recent:   filtered = base.filter {
                            guard let s = $0.status?.lowercased() else { return false }
                            return s.contains("won") || s.contains("drawn") || s.contains("tied")
                        }
        }

        if searchText.isEmpty { return filtered }
        return filtered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.teams?.joined(separator: " ").localizedCaseInsensitiveContains(searchText) == true)
        }
    }

    /// Convenience subset — only the matches that are currently live.
    var liveMatches: [Match] {
        guard case .loaded(let m) = loadingState else { return [] }
        return m.filter { $0.isLive }
    }

    /// `true` when at least one match is in-play; used to show/hide the "Live Now" strip.
    var hasLive: Bool { !liveMatches.isEmpty }

    // MARK: - Load / Refresh

    /// Triggers the initial data fetch only when the view model is in the `idle` state.
    /// Calling this from `.task {}` is safe — it will no-op if already loading or loaded.
    func load() async {
        guard case .idle = loadingState else { return }
        loadingState = .loading
        await fetch()
    }

    /// Forces a fresh network request regardless of current state (used by pull-to-refresh).
    func refresh() async {
        isRefreshing = true
        await fetch()
        isRefreshing = false
    }

    /// Never call directly — use `load()` or `refresh()`.
    ///
    /// Centralises the network call and error handling so `load` and `refresh`
    /// don't duplicate logic.
    private func fetch() async {
        do {
            let matches = try await service.fetchCurrentMatches()
            allMatches = matches
            loadingState = .loaded(matches)
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }
}

// MARK: - MatchDetailViewModel

/// View model for a single match detail screen.
/// Owns the selected scorecard tab and the refresh state for the detail pull-to-refresh.
@MainActor
@Observable
final class MatchDetailViewModel {
    var match: Match
    var isRefreshing: Bool = false
    var selectedTab: ScorecardTab = .scorecard

    init(match: Match) {
        self.match = match
    }

    /// Simulates a live-data refresh for the detail view.
    /// In a production app, replace the `Task.sleep` with a real `match_info` endpoint call.
    func refresh() async {
        isRefreshing = true
        // In real app: fetch updated match_info by id
        try? await Task.sleep(nanoseconds: 600_000_000)
        isRefreshing = false
    }
}

// MARK: - Enums

/// Filter options presented in the HomeView filter chip bar.
enum MatchFilter: String, CaseIterable {
    case all      = "All"
    case live     = "Live"
    case upcoming = "Upcoming"
    case recent   = "Recent"
}

/// Tabs available inside the match detail bottom-tab bar.
enum ScorecardTab: String, CaseIterable {
    case scorecard = "Scorecard"
    case info      = "Match Info"
}
