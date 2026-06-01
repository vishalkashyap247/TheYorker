# Models

Single file: `Match.swift`. Owns all data types that cross the network/app boundary and all mock fixtures.

---

## Types

### `CricAPIResponse<T: Codable>`

Generic envelope for every CricAPI v1 response. The API always wraps its payload in `{ "data": ..., "status": "success", "info": { ... } }`.

```swift
struct CricAPIResponse<T: Codable>: Codable {
    let data: T?
    let status: String?
    let info: APIInfo?
}
```

`CricAPIService` decodes this as `CricAPIResponse<[Match]>` and throws `CricAPIError.apiError` when `status != "success"`.

### `APIInfo`

Quota metadata attached to every response. Fields: `hitsToday`, `hitsUsed`, `credits` (all `Int?`). Useful for surfacing API budget warnings; currently decoded but not displayed.

### `Match`

The primary domain model. Conforms to `Codable`, `Identifiable`, and `Hashable`. `Hashable` is required because `HomeView` and `ScheduleView` use `NavigationLink(value: match)`, which requires the value type to be `Hashable`.

Key stored properties:

| Property | Type | Notes |
|---|---|---|
| `id` | `String` | CricAPI match UUID |
| `name` | `String` | Full name e.g. "India vs Australia, 2nd ODI" |
| `matchType` | `String?` | Raw format string from API: "odi", "t20", "test", "ipl" |
| `status` | `String?` | Human-readable status; terminal keywords signal match end |
| `venue` | `String?` | Full ground name |
| `date` | `String?` | ISO date portion "yyyy-MM-dd" |
| `dateTimeGMT` | `String?` | ISO-8601 datetime in GMT |
| `teams` | `[String]?` | Exactly two team names when populated |
| `score` | `[Score]?` | One entry per innings batted so far |
| `seriesId` | `String?` | Decoded from JSON key `"series_id"` |

Computed helpers (no stored state, purely derived):

- `team1` / `team2` — safe-subscript into `teams`, returns `"TBD"` if absent
- `team1Scores` / `team2Scores` — filters `score` by matching team name in the `inning` string
- `latestScore` — `score?.last`
- `isLive` — `true` when score data exists and `status` contains none of the terminal keywords ("won", "drawn", "tied", "no result", "yet to bat", "match not")
- `matchTypeLabel` — normalises raw format strings to display labels: "T20", "ODI", "TEST", "IPL"
- `shortName` — match name up to the first comma (strips series context)
- `seriesName` — everything after the first comma, trimmed

### `Score`

A single innings entry from the `score` array. Stored properties: `r` (runs, `Int?`), `w` (wickets, `Int?`), `o` (overs, `Double?`), `inning` (full string, e.g. "India Inning 1").

Computed helpers:

- `runs`, `wickets`, `overs` — safe defaults (0 / 0.0) for display without unwrapping
- `formatted` — long form "198/3 (32.4)" used in detail views
- `shortFormatted` — compact "198/3" for cards and widgets
- `inningShort` — human label: "1st Inn" or "2nd Inn"

### `Array` safe subscript

```swift
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

Used throughout the app wherever CricAPI may return fewer array elements than expected.

---

## Mock data

`Match.mockMatches` is a static array of six complete fixtures designed to cover all filter categories:

| ID | Teams | State |
|---|---|---|
| `mock_1` | India vs Australia | Live — ODI, mid-innings |
| `mock_2` | England vs New Zealand | Recent — Test, completed |
| `mock_3` | Pakistan vs South Africa | Live — T20, mid-chase |
| `mock_4` | West Indies vs Sri Lanka | Upcoming — ODI, not started |
| `mock_5` | Bangladesh vs Zimbabwe | Recent — T20, completed |
| `mock_6` | India vs Australia | Upcoming — ODI, future date |

Pre-filtered convenience subsets (`mockLive`, `mockUpcoming`, `mockRecent`) are available for tests and targeted previews. `Match.mockMatch` (singular) returns `mockMatches[0]` — used when a single match is needed, e.g. starting a mock Live Activity from Settings.
