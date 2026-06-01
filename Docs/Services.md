# Services

Single file: `CricAPIService.swift`. Handles all network communication with the CricAPI v1 REST API.

---

## `CricAPIService`

A `final class` singleton accessed via `CricAPIService.shared`. All public methods are `async throws`. The service never touches the UI directly; callers receive a `[Match]` array or a typed `CricAPIError`.

```swift
final class CricAPIService {
    static let shared = CricAPIService()
}
```

The session is configured with a 15-second request timeout so the UI does not hang indefinitely on slow or unreachable networks.

---

## Mock bypass

`shouldUseMock` is a private computed property that checks `UserDefaults.standard` for the key `"useMockData"` first, falling back to `APIConfig.useMockData` only when the key is absent. This means the Settings toggle overrides the compile-time default at runtime without a rebuild.

When mock mode is active, every public method sleeps for a short duration before returning the fixture data from `Match.mockMatches`:

| Method | Mock sleep |
|---|---|
| `fetchCurrentMatches()` | 800 ms |
| `fetchMatches(offset:)` | 600 ms |
| `searchMatches(query:)` | 400 ms |

The sleep exists specifically so that `LoadingState.loading` is visible and exercisable during development and testing.

---

## Public API

### `fetchCurrentMatches() async throws -> [Match]`

Returns matches that are currently in progress or started today, using the `/currentMatches` endpoint. Called by `MatchesViewModel.load()` and `MatchesViewModel.refresh()`.

### `fetchMatches(offset: Int = 0) async throws -> [Match]`

Returns the full schedule page, using the `/matches` endpoint with pagination. The `offset` parameter advances through result pages (CricAPI default page size is 25).

### `searchMatches(query: String) async throws -> [Match]`

Case-insensitive filter against match `name` and joined `teams` string. In mock mode the filter runs locally. In live mode it fetches the full schedule then filters client-side (CricAPI v1 has no server-side search endpoint).

---

## Private `fetch(endpoint:offset:)` helper

Shared implementation used by `fetchCurrentMatches` and `fetchMatches`. Steps:

1. Guards that `APIConfig.apiKey != "YOUR_CRICAPI_KEY_HERE"` — throws `CricAPIError.noAPIKey` early to prevent requests with the placeholder.
2. Builds the URL with `URLComponents`, appending `apikey` and `offset` query items.
3. Performs `session.data(from:)` and checks for HTTP 200.
4. Decodes `CricAPIResponse<[Match]>` with `JSONDecoder`.
5. Checks `decoded.status == "success"`; any other value throws `CricAPIError.apiError`.
6. Returns `decoded.data ?? []`.

---

## `CricAPIError`

```swift
enum CricAPIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(String)
    case apiError(String)
    case noAPIKey
}
```

All cases implement `errorDescription` for human-readable strings. `MatchesViewModel` catches these and stores the description in `LoadingState.error(String)`, which `HomeView` and `ScheduleView` display via `EmptyStateView`.
