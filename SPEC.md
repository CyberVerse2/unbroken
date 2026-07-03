# Unbroken — grilled spec (v1)

*Output of a /grill-me session, 2026-07-02. All open questions have been answered;
this spec is final for v1. Decisions marked **you** were answered directly;
decisions marked **default** used the interviewer's recommendation and were
accepted.*

## What this is

**Unbroken** — a free, open-source macOS habit tracker. Working title was
"Streaks for Anything"; renamed to avoid the trademarked Streaks app.
Personal tool first: it exists because you work at your Mac all day and a phone
habit app is out of sight. Success metric: **you still use it in 3 months**, and
other people can grab it from GitHub.

## Product thesis (confirmed)

The menu bar icon **is** the product. What makes you open the popover on day 40
is ambient guilt: an always-visible icon whose state says "you have unfinished
habits today." Everything else is supporting cast. Consequence: **design and
build the icon states before anything else** — done / partial / untouched /
streak-at-risk (late in the day) need to be distinguishable at 16×16 px at a
glance, in light and dark menu bars.

## Decisions

| Decision | Choice | Source |
|---|---|---|
| Platform | macOS only (for now) | **you** |
| Core mechanic | Manual daily check-ins on user-defined habits | **you** |
| Audience | You first; free/open source for everyone else | **you** |
| Surfaces (eventual) | Menu bar + window + widget | **you** |
| **V1 surface** | **Menu bar only** — icon reflects today's state, popover lists habits with one-click check-in | default |
| Streak rule (v1) | Strict daily: miss a day, streak dies. Flexible frequency / freezes deferred | default |
| Day boundary | Custom day-end hour (default 3 AM) so a 12:30 AM check-in counts for "today" | default |
| Backfill | Yesterday only, nothing older | default |
| Distribution | Notarized DMG via GitHub Releases; Homebrew cask later; no App Store in v1 | default |
| Data | Local only — atomic JSON store in Application Support. No accounts, no sync (SwiftData/CloudKit possible later) | default |
| Stack | Swift 6 + SwiftUI, MenuBarExtra, SwiftPM (no .xcodeproj); `make app` assembles the bundle | default |
| Name | **Unbroken** | **you** |
| "For anything" | Real, not aspirational: pluggable data sources are the long-term direction | **you** |

## V1 scope — build exactly this, nothing else

1. **Icon states first**: done / partial / untouched / at-risk, legible at menu
   bar size in light and dark. This is milestone 0, before any data model.
2. Create / rename / delete a habit (name + emoji).
3. Menu bar popover: today's habits, one click to check in / undo.
4. Current streak + best streak per habit, computed with the custom day-end rule.
5. Backfill yesterday from the popover.
6. That's it. Use it daily for two weeks before writing another feature.

## Architecture constraint from "pluggable sources = yes"

V1 ships manual check-ins only, but the data model must not hard-code that:

- A check-in is an **Entry** `{habit, date, source, timestamp}` where v1's only
  source is `.manual`.
- A **Habit** owns a *completion rule* (v1: "≥1 entry per day") so future
  sources (git commits, app usage, Shortcuts, webhooks) can feed entries without
  touching streak logic.
- Streak computation reads entries only — it never knows or cares where they
  came from.

Deferred but now on the roadmap (in rough order): Shortcuts action (cheapest
external source), local webhook/CLI (`unbroken done reading`), then watchers
(git, app usage).

## Shipped in v3 (2026-07-03) — the full grilled vision

The v1 discipline held long enough to prove the product; then we built out the
three surfaces and gave "for anything" teeth:

- **Main window** — sidebar (Habits / Settings); per-habit cards with 26-week
  GitHub-style history grids, current/best streak, total check-ins; drag to
  reorder; rename/delete. Settings: day-end hour, at-risk window, data location.
- **`unbroken` CLI** — `list` / `done <habit>` / `undo` / `status`, writing
  entries with `source: .cli`. First external source; proves the pluggable model.
- **Cross-process live reload** — `HabitStore.startWatchingForExternalChanges()`
  watches the store file, so a CLI check-in updates the running app's menu bar
  ring within ~200ms. `HabitStore.snapshot()` gives out-of-process readers
  (widget, `unbroken status`) a lock-free view.
- **Widget** — real WidgetKit small + medium. Built and bundled; blocked from
  the gallery only by ad-hoc signing (needs Developer ID). See README.
- **AI-generated app icon** — matte-ceramic cream ring + orange break, generated
  then masked to the macOS squircle.

49 tests pass. Engine unchanged in behavior — every new surface is just another
reader/writer of the same `HabitStore`, exactly as the architecture constraint
promised.

## Still deferred

- Flexible frequency ("3x/week"), freeze days, per-habit rules
- iCloud sync, Mac App Store, iOS companion
- Reminders/notifications
- Auto-detected streaks (git commits, app usage) — the next external sources;
  the CLI + live-reload plumbing they'd use is already in place
- Developer ID signing to unlock the widget gallery + notarized distribution

## Formerly open questions — resolved 2026-07-02

1. **Day-40 retention:** confirmed — the guilt-tripping menu bar icon is the
   product. Icon states are milestone 0 (see product thesis).
2. **Name:** **Unbroken**. Consider renaming the `streaksforeverything` folder
   and using `unbroken` (or `unbroken-app`) as the repo handle.
3. **"For anything":** yes, it gets teeth — pluggable sources, encoded as the
   Entry/source architecture constraint above.
