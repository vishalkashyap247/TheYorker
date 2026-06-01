# TheYorkerWidgets

Separate Xcode target — a WidgetKit / ActivityKit app extension. Contains four files.

The extension cannot import any code from the main `TheYorker` target. All types it needs (design tokens, flag helpers, `MatchActivityAttributes`) are either redeclared locally or duplicated from the main target.

---

## TheYorkerWidgetsBundle.swift

The `@main` entry point for the extension. Registers both widgets with the system:

```swift
@main struct TheYorkerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MatchHomeWidget()
        MatchLiveActivityWidget()
    }
}
```

Only one `@main` struct may exist in the extension. Do not add `@main` to any other file in this target.

---

## MatchActivityAttributes.swift

Exact duplicate of `TheYorker/LiveActivity/MatchActivityAttributes.swift`. See that file's README for documentation. When modifying the `ContentState` or any static attribute, update both copies.

---

## MatchHomeWidget.swift

Implements the home-screen widget via `StaticConfiguration`. Supports `.systemSmall` and `.systemMedium` families.

### Design tokens

The file redeclares colour constants as `private extension Color` using raw RGB components since `Extensions.swift` is not compiled here. Tokens: `wAccent` (#00D084), `wLive` (#FF3B5C), `wBG` (#070C18), `wCard` (#0D1526), `wTextSec` (#6B7A99), `wTextTert` (#374869), `wDivider` (#1C2E4A).

### `WidgetMatch`

A lightweight model containing only the fields the widget UI needs (no `Codable` boilerplate, no full `Foundation` dependency chain). Separate from the main app's `Match` type.

### `MatchWidgetEntry: TimelineEntry`

Snapshot of data at a point in time. Carries `matches: [WidgetMatch]` and `isMock: Bool`. `isMock` is available for showing a "Demo" indicator during development.

### `MatchWidgetProvider: TimelineProvider`

Drives the data lifecycle:

- `placeholder` — returns three mock fixtures instantly; shown on first load before any data is available.
- `getSnapshot` — also returns mock fixtures instantly; shown in the widget gallery.
- `getTimeline` — reads `"useMockData"` from `UserDefaults(suiteName: "group.com.vishal.TheYorker")`. In mock mode returns the three fixtures and schedules a 5-minute refresh. In live mode calls `fetchMatches()` and schedules a 1-minute refresh if any match is live, 5 minutes otherwise.

The adaptive refresh interval balances score freshness (1 min for live) against battery and network cost (5 min otherwise).

`fetchMatches()` is a private async method that builds the CricAPI URL from the API key stored in the App Group, performs a `URLSession.shared.data(from:)` call, and decodes a minimal inline `Resp` struct — avoiding any dependency on the main app's `CricAPIService` or `JSONDecoder` configuration.

### `MatchHomeWidget: Widget`

Declares the `StaticConfiguration` and calls `.containerBackground(for: .widget)` with a navy-to-card gradient. This is the correct iOS 17+ pattern — the background belongs on the configuration, not inside the view hierarchy, so the system can apply its own container shape (corner radius, padding, shadow) correctly.

### `SmallWidgetView`

Format badge + optional live dot header, two team rows (flag + abbreviation + score), thin divider, status text. A `RadialGradient` live glow overlay is added when `match.isLive`. No base gradient inside this view — it comes from `containerBackground`.

### `MediumWidgetView`

Two-column layout: left `primaryPanel` (identical layout to `SmallWidgetView` with slightly larger type) separated from the right column by a fading gradient divider. The right column shows up to two `miniRow` entries for the 2nd and 3rd matches. A divider is drawn between rows but not after the last one.

### Shared helpers (file-level private functions)

- `flag(_:)` — delegates to `MatchActivityAttributes.flag(for:)`
- `typeBadge(_:)` — green capsule pill for format labels
- `liveDot` — static red dot + "LIVE" label (no animation — system policy prohibits animated widgets)

---

## MatchLiveActivityWidget.swift

Implements the Live Activity UI for the lock screen and all three Dynamic Island presentation contexts.

Redeclares the same colour constants as `MatchHomeWidget.swift` plus `wCardAlt` (#132038).

### `MatchLiveActivityWidget: Widget`

Declares an `ActivityConfiguration(for: MatchActivityAttributes.self)`. Any type mismatch between this and the main app's `Activity.request(attributes:)` call will silently break updates. The lock-screen view is wrapped with `.activityBackgroundTint(.clear)` to let the view's own background show through the system material.

### `MatchLockScreenView`

Three-row compact banner (~130 pt total):

- **Row 1** — format badge (left) + live badge (right)
- **Row 2** — flag / abbreviation / score (team 1, left-aligned) · VS · score / abbreviation / flag (team 2, right-aligned). Scores use 22 pt black rounded type with `minimumScaleFactor(0.7)` for long score strings.
- **Row 3** — overs stat pill · vertical separator · run rate stat pill · spacer · status text (right-aligned, green, truncated)

Layout constraints to respect: the system clips content taller than ~150 pt; no internal `clipShape` (system manages corners); no animations (system freezes lock-screen views). `.activityBackgroundTint` sets the background tint to `rgba(10, 16, 30, 1)` — a slightly lighter shade than `yorkerBG` so the content is legible against the lock-screen blur.

### Dynamic Island layouts

**Expanded** — three regions:
- `.leading` — team 1 flag, abbreviation, score (left-padded 4 pt)
- `.trailing` — team 2 flag, abbreviation, score (right-padded 4 pt)
- `.bottom` — live dot + status text (left) + overs and run rate (right, 50% opacity)

**Compact** — two regions:
- `compactLeading` — team 1 flag + score
- `compactTrailing` — team 2 score (or "—" if yet to bat) + flag

**Minimal** — single slot showing only `team1Score` in `wAccent` green. Used when two activities compete for the island.

`.keylineTint(Color.wAccent)` draws the green accent border around the island when it is expanded.
