# Utils

Single file: `Extensions.swift`. Pure utility — no view model dependencies, no network calls.

---

## `Color(hex:)`

Initialises a SwiftUI `Color` from a hex string. Handles 3-character shorthand, 6-character opaque RGB, and 8-character AARRGGBB (alpha in leading two digits).

```swift
Color(hex: "070C18")        // opaque 6-char
Color(hex: "FF070C18")      // with alpha (AA = 0xFF = fully opaque)
Color(hex: "08F")           // 3-char shorthand → #0088FF
```

Used throughout the app whenever a literal hex value is needed that is not already a named design token.

---

## Design tokens (`extension Color`)

All colour constants are defined here as `static let` on `Color`. Views import them via dot notation: `Color.yorkerBG`, `.yorkerAccent`, etc.

| Token | Hex | Usage |
|---|---|---|
| `yorkerBG` | `#070C18` | Page background — deepest layer |
| `yorkerCard` | `#0D1526` | Card surface |
| `yorkerCardAlt` | `#132038` | Elevated chip, setting tile, stat pill |
| `yorkerDivider` | `#1C2E4A` | Separator lines |
| `yorkerAccent` | `#00D084` | Primary CTA, live state, Track button |
| `yorkerAccent2` | `#3B82F6` | Upcoming match indicator, ODI badge, key icon |
| `yorkerLive` | `#FF3B5C` | Live badge, Stop button background |
| `yorkerGold` | `#F5C842` | Winner indicator, trophy icon |
| `yorkerOrange` | `#F59E0B` | TEST badge |
| `yorkerTextPrim` | `#FFFFFF` | Primary text (alias for `.white`) |
| `yorkerTextSec` | `#6B7A99` | Secondary / muted text |
| `yorkerTextTert` | `#374869` | Tertiary / placeholder text |

Widget files redeclare equivalent values as `private extension Color` with `wXxx` names because `Extensions.swift` is not compiled into the widget extension target.

---

## Date helpers (`extension String`)

All helpers operate on strings in ISO-8601 or `"yyyy-MM-dd"` format as returned by CricAPI.

### `matchDate: String`

Converts a datetime string to `"MMM d, HH:mm"` in the device's current timezone. Falls back to `"MMM d"` (date only) when the time component is missing, and returns `self` if the string cannot be parsed at all. Used in card headers and the Match Info tab.

### `isToday: Bool` and `isTomorrow: Bool`

Extract the first 10 characters (`"yyyy-MM-dd"`), parse with `DateFormatter`, and compare with `Calendar.current.isDateInToday(_:)` / `isDateInTomorrow(_:)`.

### `dayLabel: String`

Returns `"Today"`, `"Tomorrow"`, or a full weekday string (`"Monday, May 22"`) for use as section headers in `ScheduleView`.

### `timeOnly: String`

Extracts the `"HH:mm"` portion in the device timezone. Returns `""` when the string has no time component (i.e. it is a date-only string).

### `parseDate() -> Date?` (private)

Tries three format strings in order (`"yyyy-MM-dd'T'HH:mm:ss"`, `"yyyy-MM-dd'T'HH:mm:ssZ"`, `"yyyy-MM-dd HH:mm:ss"`) then falls back to `ISO8601DateFormatter` with `.withFractionalSeconds`. This handles the variation in CricAPI's datetime string shapes across different endpoints.

---

## Team helpers (`extension String`)

### `teamFlag: String`

Returns the emoji flag for a recognised team name, or `"🏏"` as a cricket-themed fallback. Covers 16 teams: India, Australia, England, Pakistan, New Zealand, South Africa, West Indies, Sri Lanka, Bangladesh, Zimbabwe, Afghanistan, Ireland, Netherlands, Scotland, UAE, Namibia.

### `teamShort: String`

Returns the standard ICC three-letter abbreviation for the 12 primary teams, or `String(prefix(3)).uppercased()` for any unrecognised name.

---

## Gradient helpers (`extension LinearGradient`)

### `yorkerLiveGlow() -> LinearGradient`

Subtle two-stop gradient from `yorkerCard` to `yorkerAccent` at 8% opacity, flowing from `.topLeading` to `.bottomTrailing`. Used as the background of live match cards and the Track button glow; implies activity without being visually loud.
