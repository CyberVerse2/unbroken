<img src="Support/Brand/AppIcon-master.png" alt="Unbroken" width="128">

# Unbroken

A free, open-source macOS habit tracker. Keep your streaks unbroken —
your flame stays lit, or gutters to orange when the day's running out.

## The idea

The menu bar icon **is** the product. It sits in your eyeline all day as a
single flame — your streak, still burning:

| State | Icon |
|---|---|
| No habits yet | faint flame outline |
| Nothing done today | hollow flame outline |
| Partway there | flame filling from the base |
| Everything done | solid flame |
| Day ending, habits unfinished | **hot orange flame** |

You check in with one click from the popover. Miss a day and the streak dies —
strict daily, with two mercies: the logical day ends at 3 AM (a 12:30 AM
check-in still counts for "today"), and you can backfill yesterday, but nothing
older.

## Surfaces

- **Menu bar popover** — the daily glance and one-click check-in.
- **Main window** — per-habit history grids (GitHub-contributions style),
  streak stats, reordering, and settings. Open it from the popover header.
- **`unbroken` CLI** — check in from a terminal or script (see below).
- **Widget** — WidgetKit small + medium. Built and bundled, but macOS only
  surfaces widgets from Developer-ID-signed apps; an ad-hoc build like this
  won't appear in the gallery until it's properly signed. See
  [Widget status](#widget-status).

## The CLI

```sh
make cli                 # builds dist/unbroken
cp dist/unbroken /usr/local/bin/   # put it on your PATH

unbroken                 # list habits with today's status + streaks
unbroken done read       # check in "Read…" today (prefix or emoji match)
unbroken done gym --yesterday
unbroken undo read
unbroken status          # "2/4 done · at risk" — exit 0 only when all done
```

Check-ins land in the same store as the app (`source: .cli`), and the running
app picks them up live — a terminal `unbroken done` lights up the menu bar flame
within a heartbeat. `unbroken status` is designed for shell prompts and scripts.

## Design principles

- **Local only.** One JSON file in `~/Library/Application Support/Unbroken/`.
  No accounts, no sync, no telemetry. The app, CLI, and widget all read it.
- **Manual today, anything tomorrow.** Every check-in is an `Entry` with a
  `source`. The streak engine never looks at the source — so the CLI, Shortcuts
  actions, git-commit watchers, and webhooks all feed streaks without touching
  streak logic.

## Build

Requires Xcode 16+ command line tools (Swift 6).

```sh
make test    # run the engine test suite (49 tests)
make app     # build dist/Unbroken.app (menu bar + window + embedded widget)
make cli     # build dist/unbroken
make run     # build and launch the app
```

There is no `.xcodeproj` — it's a plain Swift package. `make app` assembles
and ad-hoc-signs the bundle.

## Widget status

The widget is real WidgetKit code (small + medium), packaged as a valid,
codesign-verified `.appex` inside the app bundle. But macOS's plugin daemon
refuses to register widget extensions from **ad-hoc-signed** host apps, so it
won't show up in the widget gallery from a `make app` build. A Developer ID
certificate + provisioning profile is the only unlock; the code and packaging
are already in place for when that's available.

## License

MIT — see [LICENSE](LICENSE).
