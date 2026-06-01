# ViewModels

Single file: `MatchesViewModel.swift`. Contains two view models, one state enum, and two filter enums.

---

## `LoadingState<T>`

```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
}
```

Used as the type of `MatchesViewModel.loadingState` (where `T = [Match]`). Every view that displays async data switches exhaustively over this enum rather than checking boolean flags. The `.idle` case exists so that `load()` can guard against being called more than once without resetting already-loaded data.

---

## `MatchesViewModel`

Shared by `HomeView` and `ScheduleView`. Each screen creates its own instance via `@State private var vm = MatchesViewModel()` — they are not sharing a single instance.

Declared `@MainActor @Observable` so all property mutations are on the main thread and SwiftUI re-renders only the views that read a changed property.

### Stored state

| Property | Type | Notes |
|---|---|---|
| `loadingState` | `LoadingState<[Match]>` | Drives the view's content switch |
| `searchText` | `String` | Bound to `.searchable(text:)` |
| `selectedFilter` | `MatchFilter` | Active filter chip |
| `isRefreshing` | `Bool` | Shows spinner in the toolbar refresh button |
| `allMatches` | `[Match]` (private set) | Unfiltered — used for stats strip counts |

### Computed stats (always from `allMatches`)

- `totalLiveCount` — matches where `isLive == true`
- `totalUpcomingCount` — matches where score is empty and not live
- `totalRecentCount` — matches where status contains "won", "drawn", or "tied"

These count across the full dataset so the stats strip always reflects reality regardless of which filter chip is active.

### `filteredMatches: [Match]`

Applies `selectedFilter` to the loaded data, then applies `searchText` as a second pass. Returns `[]` in non-`.loaded` states. The `HomeView` list section and `ScheduleView` grouped list both bind to this computed property.

### `liveMatches: [Match]` and `hasLive: Bool`

Convenience subset used by `HomeView`'s "Live Now" horizontal strip. `hasLive` gates the visibility of that section.

### Load / refresh methods

`load()` transitions from `.idle` → `.loading` then calls `fetch()`. It is safe to call from `.task { }` — it no-ops if already loading or loaded. `refresh()` is called by pull-to-refresh (`.refreshable`) and the toolbar button; it sets `isRefreshing = true`, calls `fetch()`, then clears it. Both delegate to the private `fetch()` which calls `CricAPIService.shared.fetchCurrentMatches()` and populates `allMatches` and `loadingState`.

---

## `MatchDetailViewModel`

Owns the state for a single match's detail screen. Initialised with a `Match` value and stored on the view via `@State`.

```swift
@MainActor @Observable final class MatchDetailViewModel {
    var match: Match
    var isRefreshing: Bool = false
    var selectedTab: ScorecardTab = .scorecard
    init(match: Match)
    func refresh() async
}
```

`refresh()` currently sleeps 600 ms to simulate a live-data round trip. In a production version, replace the sleep with a call to a `match_info` endpoint keyed on `match.id`. `selectedTab` drives the custom segmented control in `MatchDetailView`.

---

## `MatchFilter`

```swift
enum MatchFilter: String, CaseIterable {
    case all      = "All"
    case live     = "Live"
    case upcoming = "Upcoming"
    case recent   = "Recent"
}
```

`CaseIterable` allows `HomeView` to iterate all cases in `ForEach` to build the filter chip bar. The `rawValue` strings are the chip labels.

## `ScorecardTab`

```swift
enum ScorecardTab: String, CaseIterable {
    case scorecard = "Scorecard"
    case info      = "Match Info"
}
```

`CaseIterable` allows `MatchDetailView` to iterate both cases to build the custom tab bar without hardcoding labels.
