# AGENTS.md

PocketBase is a Go backend library + single-file app. The Go package lives at the repo
root (no `main` package), the admin dashboard SPA is under `ui/` and is embedded into
the Go binary.

## Commands

- All tests: `go test ./...` (`make test` adds `-v --cover`). Std `testing` package only.
- Single test: `go test ./apis -run TestCollection -v` (standard Go, no special runner).
- Lint: `make lint` (golangci-lint with config `golangci.yml`). The config uses `version: "2"` syntax — use golangci-lint v2, not v1.
- Run the dev server: `cd examples/base && go run main.go serve` (serves on `http://localhost:8090`, reloads UI from `ui/dist`).
- JSVM type definitions (committed, must match Go binds): `make jstypes` (`go run ./plugins/jsvm/internal/types/types.go`). Don't commit changes to the generated `types.d.ts` if you haven't run this.

## UI (Superuser dashboard)

- Svelte + Vite in `ui/`; needs Node 24+ (CI used >=25).
- `cd ui && npm install && npm run dev` → dev server on :5173, expects backend at :8090 (override via `ui/.env.development`).
- `cd ui && npm run build` regenerates `ui/dist`, which is embedded via `//go:embed all:dist` (`ui/embed.go`). `ui/dist` is committed — any UI change must be built and the `dist` committed, or the binary keeps serving stale UI. CI fails with a goreleaser "dirty error" if `dist` is out of date.

## Architecture

- `core/` — app, DB, models (collections/records/fields), and the entire event/hook system. Everything is event-driven: custom logic binds handlers via `app.OnServe()`, `app.OnModelCreate()`, etc. Handlers compose as middleware chains and MUST call `e.Next()`.
- `apis/` — one HTTP handler file per API endpoint (e.g. `record_auth_with_password.go`, `record_crud.go`), registered from `apis/serve.go`.
- `forms/` — validated request "forms" (record upsert, test email, etc.).
- `mails/` — transactional email templates.
- `migrations/` — system migrations registered in `init()` via `core.SystemMigrations.Register`. Follow the existing `UNIX_TIMESTAMP_description.go` naming — the list is sorted by filename.
- `cmd/` — CLI commands (`serve`, `superuser`).
- `plugins/` — optional features wired up in `examples/base/main.go` (jsvm, migratecmd, ghupdate). `Makefile` `jstypes` target lives under `plugins/jsvm/internal/types`.
- `tools/` — reusable standalone helpers (hook, router, search, routine, etc.).

## Testing quirks

- Types under `tests/data/` (`.db` fixtures + `storage/`) are committed and cloned to a temp dir by `tests.NewTestApp()`/`tests.ApiScenario`; `app.Cleanup()` removes the clone. Schema-affecting changes to system migrations may require regenerating these fixtures.
- API tests use the `tests.ApiScenario{...}.Test(t)` pattern with `ExpectedContent`/`ExpectedEvents` assertions (see `tests/api.go`). `TestApp` counts every bound core event — set `ExpectedEvents` precisely (see the `"*"` semantics in `tests/api.go`).
- `core/TestNotifyWatcher_SettingsUpdate` is flaky on macOS (~7/10 failures) due to fsnotify/kqueue timing of the cross-app settings-sync watcher (`core/notify_watcher.go`). It's a known pre-existing flake — ignore its failure; treat the suite as green if this is the only failing test.

## Gotchas

- Runtime data lives in `pb_data/`, `pb_backups/`, `pb_hooks/`, `pb_migrations/`, `pb_public/` relative to the executable — don't add them to the repo.
- `modernc_versions_check.go` pins expected `modernc.org/sqlite`/`modernc.org/libc` versions and warns if you bump them. Don't change them without bumping this check too.
- Build tags swap SQLite driver/UI: `no_default_driver` (`core/db_connect_nodefaultdriver.go`) and `no_ui` (`ui/embed_no_ui.go`).
- Release builds stamp the `Version` var via ldflags; `pocketbase.Version` in `pocketbase.go` is `(untracked)` locally.
- Go 1.25+ required (go.mod), CI pins Go >=1.26.5.
- Upstream contribution policy: PRs are currently restricted to collaborators and LLM-generated PRs are explicitly not welcome (see README) — prefer issues/discussions when contributing upstream.
