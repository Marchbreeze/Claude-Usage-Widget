# Claude Usage Widget — Design

Date: 2026-06-11
Status: Approved by user (display value = usage %, not remaining)

## Overview

A macOS menu bar app that shows Claude usage as: Claude character icon (orange) + mini progress bar + percentage text. Supports two data sources, selected in Settings: Claude subscription (Pro/Max/Enterprise seat) usage, or Anthropic API spend against a monthly budget. Distributed as an unsigned .app via GitHub Releases, built by GitHub Actions.

## Requirements

- Menu bar UI: small Claude character icon, horizontal progress bar, numeric percent (e.g. `73%`).
- Color: Claude orange `#D97757` normally; red `#E5484D` when usage > 80% (threshold fixed at 80, not configurable — YAGNI).
- Displayed value is the **usage percentage** (not remaining).
- Subscription mode: 5-hour session utilization shown in the menu bar; dropdown shows both 5-hour and 7-day utilization with reset countdowns.
- API mode: current calendar month spend (USD) divided by a user-configurable monthly budget (default $200). Dropdown shows spend amount and budget.
- Mode is chosen in Settings; exactly one mode is active at a time.
- Downloadable by other users: GitHub Releases zip of the .app, built on CI.

## Architecture

Swift Package (SwiftPM, no Xcode project file) with two targets, macOS 13+:

1. **UsageCore** (library, fully unit-testable, no AppKit):
   - `UsageSnapshot` model: `percent: Double`, `detail` fields, `fetchedAt`.
   - `OAuthUsageParser`: parses `/api/oauth/usage` JSON → 5h/7d utilization + reset dates. Tolerant parsing (unknown fields ignored; missing fields → error case, never crash).
   - `CostReportParser`: parses `/v1/organizations/cost_report` JSON → month-to-date USD sum.
   - `PercentMath`: clamping (0–100), budget percent calc, threshold check (`isOverThreshold(percent) = percent > 80`).
   - `CredentialsParser`: parses Claude Code Keychain JSON → access token + expiry.

2. **ClaudeUsageWidget** (executable, AppKit/SwiftUI):
   - `AppDelegate` + `StatusItemController`: owns `NSStatusItem`; renders icon + progress bar + percent via `NSHostingView` (SwiftUI `StatusBarView`).
   - `KeychainReader`: reads generic password service `"Claude Code-credentials"` (read-only; never writes or refreshes the token — refreshing could invalidate Claude Code's session).
   - `SubscriptionProvider`: Keychain token → `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20`. Poll every 60 s.
   - `APICostProvider`: Admin key from app's own Keychain item → `GET https://api.anthropic.com/v1/organizations/cost_report?starting_at=<first of month>` with `x-api-key` + `anthropic-version: 2023-06-01`. Follows pagination. Poll every 5 min.
   - `UsageProvider` protocol unifies both: `func fetch() async throws -> UsageSnapshot`.
   - `SettingsStore`: UserDefaults for mode + budget; Keychain (app's own service) for Admin API key. Launch-at-login via `SMAppService`.
   - `SettingsWindow` (SwiftUI): mode picker, Admin API key field, monthly budget field, launch-at-login toggle.
   - Dropdown menu (`NSMenu`): detail rows (5h %, 7d %, reset countdown — or spend $/budget), error reason row when degraded, Settings…, Quit.

The exact JSON schema of `/api/oauth/usage` is undocumented; the parser is written against the known community-observed shape and verified against the live endpoint during implementation on the user's machine. Both parsers must be tolerant of additive schema change.

## Data flow

Timer → active `UsageProvider.fetch()` → `UsageSnapshot` → `StatusItemController` updates SwiftUI state → menu bar redraws. Last good snapshot is kept in memory and on disk (`Application Support/ClaudeUsageWidget/last-snapshot.json`) so a value shows immediately on relaunch.

## Error handling

- No Keychain credentials / expired token (subscription mode): gray icon + `—`; dropdown row: "Claude Code 로그인이 필요합니다 (`claude` 실행)".
- No Admin key (API mode): gray `—`; dropdown prompts to open Settings.
- Network failure / HTTP 429 / 5xx: keep showing last good value, mark dropdown with "마지막 갱신 N분 전"; exponential backoff (max 15 min) on repeated failures.
- Malformed response: treated as fetch failure (above), never crash.

## Testing

`swift test` in CI covers UsageCore: parser fixtures (good, missing-field, extra-field, paginated cost report), percent math, threshold boundary (80.0 → orange, 80.1 → red), credentials parsing, month-window date calc. UI layer is thin and not unit-tested.

## Distribution

- Repo: `~/Documents/GitHub/Claude-Usage-Widget` → GitHub.
- GitHub Actions (`macos-latest`): on every push run `swift test`; on tag `v*` additionally `swift build -c release`, assemble `ClaudeUsageWidget.app` (script copies binary, Info.plist with `LSUIElement=true`, icon), zip, upload to GitHub Releases.
- README: install steps incl. first-launch for unsigned apps (`우클릭 → 열기` or `xattr -cr`), requirement that Claude Code is installed/logged-in for subscription mode.
