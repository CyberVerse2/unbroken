# Unbroken — flame design brief

Distilled from `Unbroken.dc.html` (claude.ai/design project "Design Unbroken app").
This is the source of truth for the v4 UI. Implement natively in SwiftUI.

## Identity

Warm, cozy, playful. The motif is **fire / streak-flame** (🔥), not the old ring.
Cream cards floating on a peach-orange gradient. Rounded, soft-shadowed, friendly.

## Type (see `Theme.swift`)

- **Bricolage Grotesque** — display: headings, streak numbers, habit names, stat
  numbers. Weights 700–800. `Theme.display(size, weight)`.
- **Hanken Grotesk** — everything else (body, labels, buttons). `Theme.text(...)`.

## Color (all in `Theme.swift`)

- Popover/card fill `#FFFBF4` (`Theme.card`); inner tiles white.
- Ink: primary `#2A211B`, then `#8A7B6E` / `#9A8A7B` / `#B0A091` / `#A8977F`.
- Lines: hairline `#F3EADF`, divider `#F1E7D9`, field border `#ECDFCC`,
  dashed `#E4D5C0`, empty grid cell `#F1E7D9`.
- Accent orange `#F26B21` (`Theme.accent`), gradient partner `#F5A623`.
- Per-habit color (`habit.color`): palette `#E2603A #E0A32E #4FA96A #2FA39A #3E7BC4 #8B5C8F`.
- Contribution/heat cells tint the habit color by level: level 0 = `#F1E7D9`;
  levels 1–4 = habit color at 0.30 / 0.52 / 0.76 / 1.0 opacity.

## Popover shape

392pt wide, ~588pt tall (min 420), corner radius 22, fill `#FFFBF4`, big soft
shadow, a little diamond pointer at top-right. `screenIn`/`popIn` transitions.
It's a single popover that swaps between screens (no separate windows).

## Screens (router state)

### 1. Onboarding — welcome (first run, step 0)
Centered: big floating 🔥 (floaty animation), headline in Bricolage 800/34
"Keep the streak **unbroken.**" (the word "unbroken" in accent color), subcopy in
`#8A7B6E`, full-width accent button "Start my first streak" → step 1, and a text
button "I already have habits →" → dashboard.

### 2. Onboarding — form (step 1) / Create habit (added later)
Back button (pill `#F3E7D6`), title "Your first habit" / "New habit".
- **Live preview tile**: emoji in a white rounded tile + draft name + "freq · 0 day streak", on a soft (habit-color @ .14) background.
- **Name** field (label uppercase `#9A8A7B`), rounded, border `#ECDFCC`.
- **Icon**: 6-col grid of emoji buttons (~12 options: 🌱🏃📖🧘💧🌙🥗✍️🎸🧹💪☕); selected = accent border + accent@.12 bg.
- **Color**: row of 6 circular swatches; selected = dark ring `#2A211B`.
- **Repeat**: 3 pill buttons Daily / Weekdays / 3× week; selected = accent border + accent@.10 bg + accent text.
- Footer button: "Light the first spark 🔥" (onboarding) / "Add habit" (create).

### 3. Dashboard (main)
- Header: uppercase date `#B0A091`, greeting in Bricolage 800/23. Greeting logic:
  all done → "You're unbroken today"; none → "Let's get going"; else "Keep it rolling".
  Gear button (top-right, pill) → settings.
- **Day progress bar**: 9pt tall, track `#F1E7D9`, fill = accent→`#F5A623` gradient
  at done/total %, animated. Caption: "N of M habits done today" / "All M done — nice fire 🔥".
- **Habit rows** (one card each, white, radius 16, hairline outline):
  - emoji tile 44×44 radius 13 on habit-color@.12
  - name (Bricolage 700/15.5, ellipsis)
  - streak line: "🔥 N" in habit color (flamePop animation when just checked),
    then a mini 14-cell grid (2 rows, 8×8 cells, habit-color tinted by level)
  - trailing **check button** 38×38 circle: unchecked = white + border `#E4D5C0`;
    checked = filled habit color + white ✓. Tap toggles today's check-in.
  - tapping the row (not the button) opens detail.
- **"+ Add a habit"** dashed button (border `#E4D5C0`, text `#A8977F`).

### 4. Detail
- Header: back, centered "emoji name" (Bricolage 700/16), gear → settings.
- **Flame counter** block (radial habit-color@soft glow bg): big floating 🔥 (52pt),
  streak number in Bricolage 800/60 habit color (flamePop on check), "DAY STREAK"
  label. CTA button below: not done → "Mark done today" (filled habit color);
  done → "✓ Done today" (habit-color@.14 bg, habit-color text).
- **Stat cards** (3, white, radius 14): Longest, Consistency %, Total days.
  Numbers Bricolage 800/22; labels 11pt `#A8977F`.
- **This week**: 7 day circles (36×36) Sun–Sat; done = filled habit color + ✓;
  today ring = habit-color@.5; label under each.
- **Last 18 weeks**: contribution grid, 7 rows × columns, 11pt cells radius 3,
  habit-color tinted by level, horizontal scroll; "Less ▢▢▢▢▢ More" legend.
- **Month heatmap**: current calendar month, 7-col grid with S M T W T F S headers,
  day-number cells tinted by completion.

### 5. Settings
- Back + "Settings" title.
- **Reminders** section: card with rows — each has an icon tile, label + desc, and
  a toggle switch (track = accent when on, `#E4D5C0` off; knob slides). Rows:
  Daily reminders, Streak sounds, Week starts Monday, Open at login.
  Persist these with `@AppStorage` (they're app prefs; notifications are NOT wired
  yet — the toggle just persists).
- **Your streaks** card: 🔥 + "N active streaks" + "X total days logged · best run Y days".
- Footer: "Unbroken" (accent, Bricolage 800/15) + "Version 1.0 · made to keep you going".

## Wiring to the real engine (UnbrokenCore) — IMPORTANT

The design's JS uses fake seeded data. Replace ALL of it with the real store:
- Check-in / undo → `store.checkIn(habit)` / `store.undoCheckIn(habit)` (today),
  `checkIn(habit, day:)` for backfill. Respect the 3 AM logical day
  (`store.settings.logicalDay(containing:)`) and today-or-yesterday backfill.
- Streak / longest / total → `store.stats(for:)` gives `.current` and `.best`;
  total = count of that habit's entries. Consistency % = total ÷ days since
  `habit.createdAt` (logical days), clamped 0–100. Never invent streak math —
  read the engine.
- Contribution grid / week / heatmap → compute completion per logical day via
  `store.isCompleted(habit, onLogicalDay:)` and Calendar math (never raw 86400s).
- Create → `store.addHabit(name:emoji:colorHex:frequency:)`; edit →
  `store.update(...)`. Frequency is stored but streak logic stays daily (note it).
- Greeting/progress read live from the store + `clock.now`.

## Motion

`flamePop` on a check-in (scale 1→1.4→.9→1), `floaty` on big flames, `screenIn`
on screen changes, spring on the check button. Respect Reduce Motion
(`accessibilityReduceMotion`) — disable the playful animations when set.
