# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix setup          # install deps and build assets (first-time setup)
mix phx.server     # start dev server (or: iex -S mix phx.server)
mix test           # run all tests
mix test test/path/to/file.exs  # run a specific test file
mix test --failed  # re-run only previously failed tests
mix precommit      # compile (warnings-as-errors), format, unlock unused deps, test — run before completing changes
```

## Environment

Copy `.env.example` to `.env` and set `STRAVA_ACCESS_TOKEN` to a valid Strava API token. The app reads this at startup via `config/runtime.exs`.

## Architecture

This is a Phoenix 1.8 + LiveView app that fetches a user's Strava activity history once on startup, caches it in ETS, and provides a reactive gear-filter UI with no API round-trips on filter changes.

### Five core domain modules (to be implemented under `lib/strava_wrapper/`)

| Module | Role |
|---|---|
| `StravaClient` | All Strava HTTP calls. Handles pagination (max 200/page), injects auth token, parses responses into `Activity` structs. Nothing else touches raw HTTP. |
| `GearResolver` | Fetches gear details by ID from Strava. Deduplicates calls — fetches each gear ID once at startup. Separated from `StravaClient` because gear is a distinct API resource. |
| `ActivityStore` | ETS-backed store. Populates at startup by calling `StravaClient` + `GearResolver`. Exposes a query interface accepting a filter map; hides ETS internals from callers. Keyed by user identity for future multi-user support. |
| `FilterEngine` | Pure functions, no side effects. Takes `(activities, filter_map)`, returns filtered list. All filter logic lives here. The filter map shape is the extension point: `%{gear_id: "abc"}` today, `%{gear_id: "abc", type: "Run"}` later. |
| `ActivityLive` | LiveView. Owns UI state (current filter + displayed activities). On mount: fetches from `ActivityStore`. On filter event: re-queries via `FilterEngine`. Thin layer — no business logic. |

Activity struct fields: `id`, `name`, `date`, `type`, `distance`, `duration`, `gear_id`, resolved gear name.

### Data flow

```
Strava API → StravaClient → ActivityStore (ETS) ← ActivityLive → FilterEngine → UI
                ↑
           GearResolver (called at startup to enrich activities with gear names)
```

## Testing strategy

- **`FilterEngine`** — primary test target. Pure functions; cover: filter by gear ID, no matches, nil gear (untagged), no filter (returns all), composed filters.
- **`ActivityStore`** — test the query interface: all activities with no filter, correct subset with filter, empty store. Do not assert on ETS internals.
- `StravaClient`, `GearResolver`, `ActivityLive` — manual testing only for now. Use `start_supervised!/1` for any process-based tests.

## Key conventions

### HTTP
Use `Req` (already in deps) for all HTTP. Never use `:httpoison`, `:tesla`, or `:httpc`.

### LiveView
- Wrap all LiveView templates with `<Layouts.app flash={@flash}>` — `Layouts` is pre-aliased in `strava_wrapper_web.ex`.
- Use LiveView **streams** for the activity list (`stream/3`, `stream_delete/3`). To filter, refetch and re-stream with `reset: true` — streams are not enumerable.
- Use `push_navigate`/`push_patch` in LiveView code; `<.link navigate={...}>` / `<.link patch={...}>` in templates. Never use deprecated `live_redirect`/`live_patch`.
- LiveView names get a `Live` suffix (`ActivityLive`). Routes in the default `:browser` scope are already aliased to `StravaWrapperWeb`, so `live "/activities", ActivityLive` resolves correctly.

### Elixir
- Never use map access syntax (`struct[:field]`) on structs — use `struct.field`.
- `if/else if` does not exist; use `cond` or `case` for multiple branches.
- Bind the result of block expressions: `socket = if connected?(socket) do ... end`.
- Use `Task.async_stream/3` with `timeout: :infinity` for concurrent enumeration.

### HEEx templates
- Interpolate values with `{@assign}` in tag bodies; block constructs (`if`, `for`, `cond`) with `<%= ... %>`.
- Conditional classes: always use list syntax `class={["base-class", @flag && "conditional-class"]}`.
- Icons: `<.icon name="hero-x-mark" class="w-5 h-5" />` — never use `Heroicons` modules directly.
- Form inputs: always use `<.input field={@form[:field]} ... />` from `core_components.ex`.
- Never write raw `<script>` tags in HEEx. For inline JS hooks, use `:type={Phoenix.LiveView.ColocatedHook}` with a `.PrefixedName`.

### CSS
- Tailwind v4 — no `tailwind.config.js`. The `app.css` import block uses `@import "tailwindcss" source(none)` — maintain this syntax.
- Never use `@apply` in raw CSS.
