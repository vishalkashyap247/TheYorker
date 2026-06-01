# TheYorker — AI Agent Reference

TheYorker is a dark-mode-only iOS cricket companion app built with SwiftUI on iOS 26 / Swift 6. It shows live scores, a full match schedule, and player-trackable Live Activities with a Dynamic Island and lock-screen banner. All data comes from the [CricAPI v1](https://cricapi.com) REST API (free tier: 100 req/day). A runtime mock-data flag removes the network dependency entirely for development and testing.

---

## Repository layout

```
TheYorker/
├── CLAUDE.md                          ← you are here
├── TheYorker.xcodeproj/
├── TheYorker/                         ← main app target
│   ├── TheYorkerApp.swift             ← @main, UINavigationBar tint
│   ├── ContentView.swift              ← TabView shell, SettingsView, UIAppearance styling
│   ├── Config.swift                   ← APIConfig (baseURL, apiKey, useMockData), AppGroup
│   ├── Models/Match.swift             ← Match, Score, CricAPIResponse, mock fixtures
│   ├── Services/CricAPIService.swift  ← singleton, async throws, mock bypass
│   ├── ViewModels/MatchesViewModel.swift  ← MatchesViewModel, MatchDetailViewModel, LoadingState
│   ├── Views/
│   │   ├── DesignSystem.swift         ← reusable components and View modifiers
│   │   ├── Home/HomeView.swift        ← HomeView, MatchCard, LiveMatchCard
│   │   ├── MatchDetail/MatchDetailView.swift  ← MatchDetailView, InningsCard, InfoRow
│   │   └── Schedule/ScheduleView.swift        ← ScheduleView, ScheduleRow
│   ├── LiveActivity/
│   │   ├── MatchActivityAttributes.swift  ← ActivityKit contract (shared type, duplicated in widgets)
│   │   └── LiveActivityManager.swift      ← @Observable singleton, start/update/end
│   └── Utils/Extensions.swift         ← Color(hex:), design tokens, String helpers, gradients
├── TheYorkerWidgets/                  ← widget extension target
│   ├── TheYorkerWidgetsBundle.swift   ← @main WidgetBundle
│   ├── MatchActivityAttributes.swift  ← DUPLICATE of app's version (required)
│   ├── MatchHomeWidget.swift          ← StaticConfiguration, small + medium layouts
│   └── MatchLiveActivityWidget.swift  ← ActivityConfiguration, lock-screen + Dynamic Island
├── TheYorkerWidgets-Info.plist        ← extension Info.plist (project root)
├── TheYorkerTests/                    ← unit test target
└── TheYorkerUITests/                  ← UI test target
```

---

## Tech stack

| Concern | Choice |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI framework | SwiftUI (iOS 26 minimum) |
| State management | `@Observable` (Swift Observation, NOT Combine / ObservableObject) |
| Async | Swift Concurrency (`async`/`await`, `Task`, `@MainActor`) |
| Live scores banner | ActivityKit — `Activity<MatchActivityAttributes>` |
| Home screen widget | WidgetKit — `StaticConfiguration` |
| Dynamic Island | `ActivityConfiguration` + `DynamicIsland { }` |
| Network | `URLSession` (raw, no third-party HTTP library) |
| Persistence | `UserDefaults` / `@AppStorage` only (no CoreData usage at runtime) |
| Data source | CricAPI v1 REST API |
| CI / remote | None — local-only private repo |

---

## Key architectural decisions

### 1. `@Observable` not `ObservableObject`

Both `MatchesViewModel` and `LiveActivityManager` use the Swift Observation macro introduced in iOS 17. SwiftUI automatically tracks only the specific properties a view reads, so there are no `@Published` annotations and no Combine pipeline. Views declare the view model with `@State private var vm = MatchesViewModel()` rather than `@StateObject`.

```swift
@MainActor @Observable final class MatchesViewModel {
    var loadingState: LoadingState<[Match]> = .idle
    var searchText: String = ""
    ...
}
```

### 2. `LoadingState<T>` enum

Instead of `isLoading: Bool` + `error: String?` booleans (which allow impossible states like `isLoading == true` and `error != nil` simultaneously), every async request is modelled as:

```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
}
```

Views switch exhaustively over this enum, making the `.error` path impossible to overlook.

### 3. `MatchActivityAttributes` is intentionally duplicated

The widget extension is a separate compilation unit and cannot import types from the main app target. `MatchActivityAttributes.swift` therefore exists verbatim in both `TheYorker/LiveActivity/` and `TheYorkerWidgets/`. When making changes to the attributes or content state, update **both files** and keep them in sync.

### 4. `containerBackground(for: .widget)` pattern

Widget backgrounds are declared on `MatchHomeWidget.body` using `.containerBackground(for: .widget) { ... }` rather than inside the view hierarchy. This is the iOS 17+ requirement; an internal `ZStack` gradient would break the system's container clipping and produce incorrect corner radius behaviour.

### 5. Mock data at runtime

`APIConfig.useMockData` sets the compile-time default. At runtime the `Settings` tab exposes a toggle that writes to `UserDefaults(standard)` key `"useMockData"`. `CricAPIService.shouldUseMock` reads that key first and falls back to `APIConfig.useMockData` only when the key is absent. The same toggle propagates to the App Group (`group.com.vishal.TheYorker`) so `MatchHomeWidget`'s timeline provider honours the same preference.

### 6. `@MainActor` on ViewModels and LiveActivityManager

All state-mutating types carry `@MainActor` at the class level. This eliminates the need for any `DispatchQueue.main.async` or `.receive(on:)` calls and satisfies Swift 6 strict-concurrency requirements: the compiler enforces that these types are only accessed from the main actor.

### 7. Hero section seamless gradient

`MatchDetailView`'s hero uses a `LinearGradient` that ends at `Color.yorkerBG` with no `clipShape`. This creates a seamless fade into the page background rather than a hard card edge, so the scoreboard floats above the content without a visible container boundary.

### 8. `PBXFileSystemSynchronizedRootGroup` for widgets

The `TheYorkerWidgets` folder is tracked as a filesystem-synchronised group in the `.xcodeproj`. Adding a new `.swift` file to the folder automatically includes it in the extension target's compile sources without any manual pbxproj editing.

---

## Data flow

```
CricAPIService.fetchCurrentMatches()
        ↓
MatchesViewModel.load() / refresh()
        ↓ (loadingState = .loaded([Match]))
HomeView                      ScheduleView
  ├─ statsStrip (all matches)
  ├─ liveNowSection → LiveMatchCard
  │       └─ Track button → LiveActivityManager.start(match:useMock:)
  │                                   ↓
  │                         Activity<MatchActivityAttributes>.request(...)
  │                                   ↓
  │                         TheYorkerWidgets renders
  │                         MatchLiveActivityWidget (lock-screen + Dynamic Island)
  └─ matchListSection → NavigationLink(value: match)
                              ↓
                         MatchDetailView
                           ├─ MatchDetailViewModel.refresh()
                           ├─ .scorecard tab → InningsCard per team
                           └─ .info tab → InfoRow list
```

---

## Design system

All colour constants live in `Utils/Extensions.swift` as `Color` static properties. The full palette (background layers → accents → text hierarchy):

| Token | Hex | Role |
|---|---|---|
| `yorkerBG` | `#070C18` | Deepest canvas — page background |
| `yorkerCard` | `#0D1526` | Card surface |
| `yorkerCardAlt` | `#132038` | Elevated chip / picker tile |
| `yorkerDivider` | `#1C2E4A` | Separator lines |
| `yorkerAccent` | `#00D084` | Cricket green — primary CTA, live states |
| `yorkerAccent2` | `#3B82F6` | Electric blue — upcoming matches, ODI badge |
| `yorkerLive` | `#FF3B5C` | Live red — badges, Stop button |
| `yorkerGold` | `#F5C842` | Winner / trophy |
| `yorkerOrange` | `#F59E0B` | Test match badge |
| `yorkerTextPrim` | `#FFFFFF` | Primary text |
| `yorkerTextSec` | `#6B7A99` | Secondary / muted text |
| `yorkerTextTert` | `#374869` | Tertiary / placeholder text |

Widget files (`MatchHomeWidget.swift`, `MatchLiveActivityWidget.swift`) redeclare the same values as `private extension Color` using raw RGB components (`wAccent`, `wLive`, etc.) because `Extensions.swift` is not compiled into the widget target.

Reusable components defined in `DesignSystem.swift`:
- `LiveBadge` — animated pulsing red dot + "LIVE" label
- `MatchTypeBadge` — colour-coded format pill (TEST / ODI / T20 / IPL)
- `FilterChip` — horizontal scroll filter pill with selected/unselected states
- `SectionHeader` — bold title with optional muted subtitle
- `EmptyStateView` — spring-animated emoji + title + subtitle placeholder
- `SkeletonMatchCard` — shimmer loading placeholder card

View modifiers:
- `.yorkerCard(radius:)` — applies `yorkerCard` background + continuous corner clip
- `.liveCard()` — live-match surface with green glow gradient + accent border

---

## Navigation

Navigation is fully `NavigationLink(value:)` based (type-safe, push-based). The destination is registered once per `NavigationStack` via `.navigationDestination(for: Match.self)`, keeping individual row/card views decoupled from navigation logic. `Match` conforms to `Hashable` to satisfy the value-based navigation requirement.

---

## API configuration

1. Get a free key from [cricapi.com](https://cricapi.com).
2. Paste it into `Config.swift` → `APIConfig.apiKey`.
3. Set `APIConfig.useMockData = false`.
4. Enable the `group.com.vishal.TheYorker` App Group on both targets in Xcode Signing & Capabilities.

The free tier provides 100 requests/day. `CricAPIService` throws `CricAPIError.noAPIKey` if the placeholder string is still present, preventing accidental requests with an invalid key.

---

## Running with mock data (default)

No configuration needed. `APIConfig.useMockData = true` is the default. The service sleeps for 600–800 ms to simulate real network latency so loading states are exercisable without a real key. Six mock fixtures are provided covering all filter categories: two live, two upcoming, two recent.

---

## Test targets

- `TheYorkerTests/` — unit tests covering models (`Match`, `Score`, array subscript), string extensions (`matchDate`, `teamFlag`, `teamShort`, `isToday`, `isTomorrow`), `LoadingState` transitions, `MatchesViewModel` filtering, and `CricAPIService` mock behaviour.
- `TheYorkerUITests/` — UI tests for home screen load, filter chip interaction, and navigation to match detail.

---

## Common change patterns

**Add a new filter category**: add a case to `MatchFilter` in `MatchesViewModel.swift`, add the filter logic in `filteredMatches`, add a label/icon in `HomeView.filterLabel(_:)` / `filterIcon(_:)`.

**Add a new design token**: add a `static let` to `extension Color` in `Extensions.swift`. If it is needed in widgets, also add the corresponding `wXxx` constant in the `private extension Color` blocks inside `MatchHomeWidget.swift` and `MatchLiveActivityWidget.swift`.

**Add a field to the Live Activity**: update `MatchActivityAttributes.ContentState` in **both** `TheYorker/LiveActivity/MatchActivityAttributes.swift` and `TheYorkerWidgets/MatchActivityAttributes.swift`. Update `LiveActivityManager.start()` and `update()` to populate the new field, and update the widget views to display it.

**Add a widget size**: add the new family to `.supportedFamilies([...])` in `MatchHomeWidget.body`, add a new view struct for it, and add a `case` to the `switch family` block in `MatchWidgetView`.
