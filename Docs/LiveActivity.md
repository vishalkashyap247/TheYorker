# LiveActivity

Two files: the shared data contract and the singleton manager.

---

## MatchActivityAttributes.swift

Defines the `ActivityAttributes` conformance that forms the contract between the main app (which starts and updates activities) and the widget extension (which renders them).

**This file is intentionally duplicated.** It exists verbatim in both:
- `TheYorker/LiveActivity/MatchActivityAttributes.swift` (this folder)
- `TheYorkerWidgets/MatchActivityAttributes.swift`

Widget extensions are separate compilation units and cannot import code from the main app target. Keeping one copy in each target is the standard approach; if you drift the two files they will silently mismatch and updates will be ignored.

### Static attributes (set once when the activity starts)

| Property | Type | Notes |
|---|---|---|
| `matchId` | `String` | CricAPI match UUID |
| `matchName` | `String` | e.g. "India vs Australia" |
| `team1` / `team2` | `String` | Full country name — used for flag lookup |
| `team1Short` / `team2Short` | `String` | Three-letter abbreviations |
| `matchType` | `String` | "ODI", "T20", "TEST", "IPL" |
| `venue` | `String` | Full ground name |

### `ContentState` (updated as the match progresses)

```swift
public struct ContentState: Codable, Hashable {
    var team1Score:  String   // e.g. "198/3"
    var team2Score:  String   // e.g. "Yet to bat"
    var overs:       String   // e.g. "32.4"
    var runRate:     String   // e.g. "6.11"
    var status:      String   // e.g. "India are batting"
    var isLive:      Bool
    var lastUpdated: Date
}
```

`lastUpdated` carries a `Date` so widget views can compute relative timestamps ("2m ago") without an additional update.

### Mock fixtures

`MatchActivityAttributes.mockAttributes` and `.mockState` provide pre-built values for previewing the Live Activity from the Settings screen without a real match.

### `flag(for:)` helper

A static method that maps team names to emoji flags. It duplicates the `String.teamFlag` logic from `Extensions.swift` because the widget extension cannot import that file.

---

## LiveActivityManager.swift

`@MainActor @Observable final class LiveActivityManager`. Singleton accessed via `LiveActivityManager.shared`. Owns the full lifecycle of all `Activity<MatchActivityAttributes>` instances.

`@MainActor` guarantees all property mutations on the main thread, satisfying Swift 6 strict concurrency. `@Observable` means views that call `isTracking(_:)` will re-render automatically when activity state changes without needing `@Published` or Combine.

### Internal state

```swift
private var activities: [String: Activity<MatchActivityAttributes>] = [:]
```

The dictionary maps `matchId → Activity`. It is the single authoritative source of truth — `LiveMatchCard` reads from here rather than maintaining local state, so button labels remain accurate even after cards scroll off-screen.

`runningMatchIds: Set<String>` exposes the dictionary keys as a read-only public property.

### `start(match:useMock:) async throws`

1. Checks `ActivityAuthorizationInfo().areActivitiesEnabled`. Throws `LiveActivityError.activitiesDisabled` with a user-actionable message if false (directs user to Settings → TheYorker → Live Activities).
2. Builds `attrs` and `state` — either from mock fixtures or from the live `Match` object.
3. Awaits `endActivity(matchId:)` for the same ID to avoid duplicate-activity errors from ActivityKit.
4. Calls `Activity<MatchActivityAttributes>.request(attributes:content:pushType:)` with a 5-minute stale date.
5. Stores the resulting `Activity` in `activities[id]`.
6. On failure wraps the underlying error as `LiveActivityError.requestFailed(String)`.

Push type is `nil` — the app polls for updates rather than using APNs push tokens. Stale date of +300 s tells the system the data may be outdated if the app has not sent a newer update within that window.

### `update(matchId:with:) async`

Pushes a fresh `ContentState` derived from the current `Match` to the running activity. Silent no-op when no activity exists for `matchId`.

### `end(match:)` and `endMock()`

`end(match:)` ends the real match's activity and also ends the hard-coded mock ID `"mock_ind_aus_001"` (in case a mock was started from Settings for the same match). `endMock()` ends only the mock activity. Both dispatch to `endActivity(matchId:)` via `Task { await ... }` so the call site can remain synchronous.

### `endAll() async`

Iterates `Activity<MatchActivityAttributes>.activities` (the system registry) and ends everything, then clears the local dictionary. Used for a full reset.

---

## `LiveActivityError`

```swift
enum LiveActivityError: LocalizedError {
    case activitiesDisabled
    case requestFailed(String)
}
```

Both cases implement `errorDescription`. The `.activitiesDisabled` message includes explicit navigation instructions ("Settings → TheYorker → Live Activities") so the user knows exactly what to do. Errors surface to the user via `.alert` in `LiveMatchCard` and `SettingsView`.
