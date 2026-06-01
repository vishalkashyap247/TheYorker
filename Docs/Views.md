# Views

Four files across three subdirectories plus the shared design system.

```
Views/
├── DesignSystem.swift
├── Home/HomeView.swift
├── MatchDetail/MatchDetailView.swift
└── Schedule/ScheduleView.swift
```

---

## DesignSystem.swift

Reusable components and `View` modifier extensions. Import nothing outside of SwiftUI — no view model dependencies.

### View modifiers

`.yorkerCard(radius:)` — applies `Color.yorkerCard` background and a continuous-corner `RoundedRectangle` clip. Default radius 18 pt.

`.liveCard()` — live-match surface: `LinearGradient.yorkerLiveGlow()` background, continuous 18 pt corner clip, accent-green gradient border stroke (1.2 pt, top-leading to bottom-trailing fade).

### `LiveBadge`

Animated red pulsing dot + "LIVE" label wrapped in a capsule pill. Two independent `@State` booleans drive two concurrent animations: `pulse` breathes the solid 7 pt dot (scale 0.9 ↔ 1.2, easeInOut, repeating); `ring` expands a 1.5 pt stroke circle from 7 pt to 16 pt and fades it out (easeOut, 1s, repeating non-reversing). Animations start in `.onAppear`.

### `MatchTypeBadge`

Format pill with a colour keyed to the match type:
- `"TEST"` → `yorkerOrange`
- `"ODI"` → `yorkerAccent2` (blue)
- `"T20"` / `"T20I"` → `yorkerAccent` (green)
- `"IPL"` → `#A855F7` (purple)
- default → `yorkerTextSec`

### `FilterChip`

Tappable capsule pill with optional leading SF Symbol icon. When `isSelected == true` the background fills with `yorkerAccent` and text/icon colour inverts to `yorkerBG` (dark). A green drop shadow appears on selection. Spring animation (`response: 0.3, damping: 0.65`) drives the transition.

### `SectionHeader`

Bold 20 pt rounded title with an optional 12 pt muted subtitle on the same baseline. Used above every grouped list.

### `EmptyStateView`

Full-width vertical stack: large emoji (54 pt), title (17 pt semibold), subtitle (13 pt muted). All three elements spring in on `.onAppear` from scale 0.4 / offset 12 pt with a 0.1 s delay.

### `SkeletonMatchCard`

Placeholder shimmer card matching the layout of `MatchCard`. A narrow translucent gradient window (`phase: CGFloat`) translates from −180 to +400 pt over 1.5 s in a repeating linear animation. The gradient is clipped to the card shape so it does not bleed outside the rounded corners. Shown while `loadingState == .loading`.

---

## Home/HomeView.swift

Main landing screen. Uses `@State private var vm = MatchesViewModel()`.

### Layout (top to bottom)

A `ScrollView` sits inside a `ZStack` that places a radial green ambient glow at the top of the screen. Content is:

1. **Stats strip** (`statsStrip`) — horizontal row of stat chips showing live / upcoming / finished counts from `vm.allMatches`. Visible only when `.loaded`. Always reflects the full dataset, not the active filter.
2. **Filter bar** (`filterBar`) — horizontal `ScrollView` of `FilterChip` views for all `MatchFilter` cases. Changing the chip briefly sets `cardsOn = false` then back to `true` so the new list of cards animates in fresh.
3. **Content body** (`contentBody`) — switches over `vm.loadingState`:
   - `.idle` / `.loading` → four `SkeletonMatchCard` placeholders
   - `.loaded` → `loadedBody` (live strip + match list)
   - `.error` → `EmptyStateView` + Retry button that calls `vm.refresh()`

### Live Now section

Horizontal `ScrollView` with `scrollClipDisabled()` so card drop shadows are not clipped by the scroll view's bounds. Visible only when `vm.selectedFilter == .all && vm.hasLive`. Each `LiveMatchCard` is wrapped in `NavigationLink(value: match)` with `LiveCardButtonStyle` (spring scale 0.97 on press). Cards stagger in with a 70 ms per-card delay.

### Match list section

Vertical `ForEach` of `MatchCard` views, each wrapped in `NavigationLink(value: match)` with `MatchCardButtonStyle` (scale 0.975 on press). Cards stagger with 55 ms per-card delay.

### `MatchCard`

Three-section card: header (format badge + live indicator + date + venue), teams panel (two `teamPanel` columns separated by a VS bubble), footer (status icon + status text + chevron). Background is `LinearGradient.yorkerLiveGlow()` for live matches or flat `yorkerCard` otherwise. Border strokes and drop shadows shift colour to match live / non-live state. The winner team's score text turns `yorkerAccent` and a gold trophy icon appears.

### `LiveMatchCard`

Fixed-width (280 pt) card for the horizontal live strip. Contains the Track / Stop Live Activity button. State logic:

- `isTracking` reads directly from `LiveActivityManager.shared.isTracking(match.id)` — not local `@State` — so the button label stays accurate after the card is scrolled off-screen and back.
- `isStarting: Bool` prevents double-tap while the async `start()` call is in flight and shows a `ProgressView` spinner in the button.
- When `isTracking == false`, the button is `yorkerAccent` (green) with a radio-wave icon.
- When `isTracking == true`, the button is `yorkerLive` (red) with a white filled circle, labelled "Stop".
- On error, `laError: String?` triggers an `.alert` so the failure message reaches the user.

---

## MatchDetail/MatchDetailView.swift

Full-screen detail pushed via `NavigationLink(value: match)`. Uses `@State private var vm: MatchDetailViewModel` initialised with the passed `Match`.

### Entrance animations

Two `@State` booleans (`heroOn`, `contentOn`) are set in `.onAppear` with spring animations. `heroOn` fires immediately; `contentOn` fires with a 0.2 s delay. Individual hero sub-sections (badges, scoreboard, status banner, venue) add further per-element delays (0.05 s, 0.1 s, 0.2 s, 0.25 s) for a staggered cascade feel.

### Hero section

No `clipShape`, no `.shadow` on the outer container. A `LinearGradient` ending at `Color.yorkerBG` creates a seamless invisible bottom edge. A green `RadialGradient` overlay is added only when `match.isLive`. The hero contains:
- Badges row (format, live, date)
- Scoreboard: two `heroTeam` columns separated by a "VS" label
- Status banner: floating capsule pill coloured green (live) or gold (completed)
- Venue label with mappin icon

`heroTeam(team:scores:isWinner:align:)` renders flag emoji, team short name (with optional gold trophy), full team name, and score rows. The latest innings score is 30 pt black rounded; earlier innings are 18 pt muted. `contentTransition(.numericText())` animates digit changes during live score updates.

### Custom tab bar

`@Namespace private var ns` creates the matched-geometry space. The green 3 pt underline bar uses `.matchedGeometryEffect(id: "tabLine_\(tab.rawValue)", in: ns)` so it slides smoothly between tab positions on a spring animation rather than cross-fading.

### Tab content transitions

Switching from Scorecard to Match Info uses an asymmetric transition: insertion from the trailing edge, removal to the leading edge — creating a left-to-right carousel feel.

### `InningsCard`

Displays a team's innings with: score hero (40 pt black numerals), overs in a muted label, three stat pills (Run Rate, Wickets, Overs), and a wickets progress bar. The progress bar animates width from 0 to the actual proportion on appear using a spring (response 0.9). Bar colour is a two-stop gradient that shifts green (0–3 wkts) → blue (4–6) → orange (7–9) → red (10, all out).

### `InfoRow`

Labelled row with a 32 pt icon square (accent colour on 12% opacity background), a 64 pt fixed-width label column, and a value that fills the remaining width. Used in the Match Info tab for Format, Venue, Date, Teams, Status.

---

## Schedule/ScheduleView.swift

Full schedule with date-grouped sections. Uses its own `@State private var vm = MatchesViewModel()` — independent of HomeView's instance.

Matches are grouped by `date` key via `Dictionary(grouping:)` and sorted lexicographically ascending (ISO "yyyy-MM-dd" strings sort correctly as dates).

### `scheduleList`

`LazyVStack` with `pinnedViews: [.sectionHeaders]` inside a `ScrollView`. Section headers are date labels with a "TODAY" pill appended when the date string matches today. The sticky header matches `yorkerBG` so it blends as it pins.

### `ScheduleRow`

Three-column layout: time column (68 pt fixed, shows "LIVE" pill or start time + format badge) → 2 pt gradient accent divider → main content (teams, venue, optional score chips, status). Live matches use `LinearGradient.yorkerLiveGlow()` background and a green accent border. The time column divider fades from `yorkerAccent` to transparent at the bottom for live matches, and uses flat `yorkerDivider` for non-live.

Score chips appear only when at least one team has batted; they display the team abbreviation and latest innings score in `yorkerCardAlt` rounded rectangles.

`ScheduleRowButtonStyle` provides the same spring scale press (0.978) as the home screen cards.
