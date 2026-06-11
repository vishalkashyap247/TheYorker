# TheYorker

A dark-mode cricket companion app for iOS built with SwiftUI. Live scores, match schedules, and real-time Live Activities with Dynamic Island and lock-screen banners - powered by the CricAPI.

---

## Screenshots

<p align="center">

  <img src="https://github.com/user-attachments/assets/6f1b0faf-6571-4ebe-968b-f49d74aabb5a" width="200" alt="Home screen">
  <img src="Screenshots/02_live_now.png" width="200" alt="Live matches">
  <img src="Screenshots/03_match_detail_scorecard.png" width="200" alt="Scorecard">
  <img src="Screenshots/04_match_detail_info.png" width="200" alt="Match info">
</p>
<p align="center">
  <img src="Screenshots/05_schedule.png" width="200" alt="Schedule">
  <img src="Screenshots/06_settings.png" width="200" alt="Settings">
  <img src="Screenshots/07_dynamic_island_compact.png" width="200" alt="Dynamic Island">
  <img src="Screenshots/08_lock_screen_live_activity.png" width="200" alt="Lock screen Live Activity">
  <img src="Screenshots/09_dynamic_island_expanded.png" width="200" alt="Dynamic Island expanded">
</p>

---

## Features

- **Live scores** - real-time match updates from CricAPI v1 (100 req/day free tier)
- **Home screen widget** - small and medium sizes showing the active match score
- **Live Activity** - lock-screen banner + Dynamic Island compact and expanded views
- **Match schedule** - grouped by date, filterable by All / Live / Upcoming / Recent
- **Match detail** - innings scorecard with run rate, wickets, and over-by-over progress bar
- **Settings** - favourite team grid, mock-data toggle, API key configuration

---

## Tech stack

- Swift 6 + SwiftUI (iOS 26 minimum)
- `@Observable` macro - no Combine, no `ObservableObject`
- ActivityKit for Live Activities and Dynamic Island
- WidgetKit `StaticConfiguration` for home screen widget
- `URLSession` only - no third-party networking library
- `UserDefaults` / `@AppStorage` for persistence (no CoreData)

---

## Project structure

```
TheYorker/
├── TheYorker/                  - main app target
│   ├── Config.swift            - API config, mock-data flag, App Group ID
│   ├── Models/                 - Match, Score, CricAPIResponse, mock fixtures
│   ├── Services/               - CricAPIService (async/await, mock bypass)
│   ├── ViewModels/             - MatchesViewModel, MatchDetailViewModel, LoadingState<T>
│   ├── Views/
│   │   ├── DesignSystem.swift  - LiveBadge, MatchTypeBadge, FilterChip, shimmer cards
│   │   ├── Home/               - HomeView, LiveMatchCard, MatchCard
│   │   ├── MatchDetail/        - MatchDetailView, InningsCard, InfoRow
│   │   └── Schedule/           - ScheduleView, ScheduleRow
│   ├── LiveActivity/           - MatchActivityAttributes, LiveActivityManager
│   └── Utils/Extensions.swift  - Color tokens, date helpers, team flags
├── TheYorkerWidgets/           - widget extension target
│   ├── MatchHomeWidget.swift   - home screen widget (small + medium)
│   └── MatchLiveActivityWidget.swift - lock-screen + Dynamic Island
├── TheYorkerTests/             - unit tests (125 test methods)
├── TheYorkerUITests/           - UI tests (10 test cases)
└── Docs/                       - per-module markdown references
```

---

## Getting started

### 1 - Clone and open

```bash
git clone https://github.com/vishalkashyap247/TheYorker.git
cd TheYorker
open TheYorker.xcodeproj
```

### 2 - Run with mock data (no API key needed)

`Config.swift` ships with `useMockData = true`. Hit Run - six mock fixtures load immediately covering all filter categories (live, upcoming, recent). The Settings tab has a toggle to switch mock mode on/off at runtime.

### 3 - Use a real API key

1. Get a free key at [cricapi.com](https://cricapi.com) (100 requests/day)
2. Open `TheYorker/Config.swift`
3. Replace `"YOUR_CRICAPI_KEY_HERE"` with your key
4. Set `useMockData = false`
5. Enable the `group.com.vishal.TheYorker` App Group on both the app and widget targets in Xcode Signing & Capabilities

---

## Architecture notes

**State management** - `MatchesViewModel` and `LiveActivityManager` use the `@Observable` macro (Swift Observation, iOS 17+). Views read only the properties they use; there are no `@Published` annotations and no Combine subscriptions.

**`LoadingState<T>` enum** - replaces the classic `isLoading: Bool` + `error: String?` pair. The four cases (`idle`, `loading`, `loaded(T)`, `error(String)`) make impossible states unrepresentable and force exhaustive handling in every view.

**Widget background** - the home screen widget uses `.containerBackground(for: .widget) { gradient }` (iOS 17+ requirement) rather than an internal `ZStack` gradient. This lets WidgetKit apply the correct system corner radius and container clipping.

**`MatchActivityAttributes` duplication** - the widget extension is a separate compilation unit and cannot import types from the main app. The shared ActivityKit contract is kept in sync across both `TheYorker/LiveActivity/` and `TheYorkerWidgets/` manually.

**`@MainActor` on view models** - all state-mutating types carry `@MainActor` at the class level. This satisfies Swift 6 strict-concurrency without any `DispatchQueue.main.async` call sites.

---

## Design system

All colour tokens live in `Utils/Extensions.swift` as `Color` static properties.

| Token | Hex | Role |
|---|---|---|
| `yorkerBG` | `#070C18` | Page background |
| `yorkerCard` | `#0D1526` | Card surface |
| `yorkerAccent` | `#00D084` | Cricket green - primary CTA, live states |
| `yorkerAccent2` | `#3B82F6` | Electric blue - upcoming matches |
| `yorkerLive` | `#FF3B5C` | Live red - badges, stop button |
| `yorkerGold` | `#F5C842` | Winner / completed match |
| `yorkerTextPrim` | `#FFFFFF` | Primary text |
| `yorkerTextSec` | `#6B7A99` | Secondary / muted text |

---

## Tests

Unit tests are in `TheYorkerTests/` and cover models, string extensions, view model filtering and search, `LoadingState` transitions, and `CricAPIService` mock behaviour (125 test methods across 10 classes).

UI tests are in `TheYorkerUITests/` and cover the home screen load, filter chips, match card tap and navigation, pull-to-refresh, and tab switching (10 test cases).

---

## License

MIT
