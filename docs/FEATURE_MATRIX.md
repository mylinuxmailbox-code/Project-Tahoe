# Project Tahoe X86 — Feature Matrix

- **Purpose**: Track what is implemented, partially implemented, or planned
- **Status**: Updated after the first successful build and run
- **Rule**: a feature is never marked implemented because it looks right. It is implemented
  when it is connected to real behaviour, persists where required, and reports failures.

## Legend

- ✅ Implemented and connected to real behaviour (verified by a build and a run where the
  behaviour is observable; where it is only structurally verified, the row names the gap)
- 🟡 Partially implemented, with the gap named
- ⚪ Planned
- ❌ Not possible within current constraints

## Verification status of everything marked ✅

The shell **has now been built and run** (Qt 6.8.3, 2026-10-10). Where a ✅ below describes
behaviour that a run can observe, it was observed: the shell starts, renders, reads and re-writes
its settings file, and reports `152 applications found` from this machine's real `.desktop`
files. Screenshots from those runs are committed under `docs/screenshots/`.

Everything else is structural. `make check` runs 545 checks without Qt and neither compiles nor
runs anything — and it is not a substitute for a build, because the first real build found six
defects that it had been reporting as passing. Those checks are a net for accidental damage to
the source tree, not evidence that a feature works. See `build_env.md` for the build and run
evidence.

## Shell and Desktop

- Desktop surface with wallpaper: ✅ image file or URL, with a gradient fallback and a real
  error report when the image cannot be loaded
- Design token system: ✅ one shared token module consumed by every component, with light and
  dark palettes; `mode` is driven by the appearance setting
- Menu bar: ✅ active application name, live clock (real system time, updates every second),
  notification indicator with the real unread count, Control Center button, and a status area
  that reports service results and failures
- Menu bar application menus (File/Edit/View driven by the active application): ⚪
- Menu bar status items (network, battery, volume, Bluetooth): ⚪ the shell has no backend for
  them; the Control Center states this instead of showing dead controls
- Dock with pinned and running apps: ✅ pinned items persisted; running items reflect the real
  open-window model; activation launches; icons resolved from the system icon theme through the
  real lookup order (verified by render)
- Dock magnification: 🟡 hover-based single-tile scaling with a configurable strength; macOS
  neighbour magnification is not implemented
- Dock auto-hide: ✅ bottom-edge reveal strip
- Dock position: 🟡 the value is stored in the config file, but only the bottom edge is
  implemented; the Settings application states this rather than offering a dead control
- Window chrome: ✅ drag with clamping, eight resize handles honouring minimum sizes, focus on
  click, stacking, minimise, zoom, close — for applications the shell hosts
- Windows of separately launched applications: ❌ their geometry, decoration, and focus belong
  to the compositor; the shell does not pretend to manage them
- Desktop icons and context menu: ⚪
- Drag and drop on the desktop: ⚪
- Virtual desktops, full-screen, Mission Control, snapping: ⚪
- Spotlight search: ✅ unified over installed applications, real files, and settings; keyboard
  driven; every result is actionable

## System Panels

- Control Center: ✅ appearance, reduce motion, Dock icon size, magnification, auto-hide,
  notification status, and an explicit statement of what is missing
- Notification Center: ✅ real list, per-item dismiss, clear all, and an honest empty state that
  explains when another daemon owns the notification bus name
- System Settings application: ✅ appearance, wallpaper, Dock, window chrome, notification
  status, config path, trash size, and preference reload
- System Settings: network, sound, Bluetooth, displays, keyboard, accessibility, users,
  security, storage, updates: ⚪

## File Manager

- Finder application: ✅ real browsing with navigation history, up, sidebar locations from the
  XDG directories, hidden-file toggle, and a status line that distinguishes errors from
  ordinary messages
- Create folder, rename: ✅ through the filesystem service, with real error text
- Delete: ✅ moves to the freedesktop trash (recoverable)
- Restore and empty trash: ✅ trash records are read back to restore to the original path
- Open a file with the system default handler: ✅ via the application registry (`xdg-open`);
  reports honestly when no handler exists
- Search within a folder tree: ✅ bounded, does not follow symlinked directories
- Icon/list/column views: 🟡 a single list view; icons and columns are planned
- Quick Look preview, archive create/extract, cloud locations, operation progress and
  cancellation: ⚪
- Copy and move: ✅ implemented in the service with a copy-then-remove fallback across
  filesystems; the Finder UI does not expose them yet (🟡)

## Application launching

- Launch installed applications: ✅ resolved from real `.desktop` entries found in the XDG
  application directories, with `NoDisplay`, `Hidden`, and `TryExec` honoured, field codes
  stripped from `Exec`, and unresolved entries counted and reported rather than hidden
- Launch failure reporting: ✅ `Started` / `NotFound` / `Failed`, each with a reason string
  surfaced in the menu bar
- Application registry for the full app suite: 🟡 every installed application is listed; the
  shell's own applications (Finder, Settings) are hosted in-process

## Persistence

- Settings persistence: ✅ atomic `QSaveFile` writes to
  `$XDG_CONFIG_HOME/project-tahoe/shell/settings.json`, unknown keys ignored, corrupt files
  reported and never overwritten, debounced saves, and no redundant write after a load
- Shared settings model: ✅ a QML singleton, so a change in the Settings application is
  immediately visible in the Dock, the desktop, and the window layer
- Trash persistence: ✅ the freedesktop layout, readable by other file managers
- Window geometry persistence: ⚪ window positions are not saved between runs yet

## Infrastructure

- Reproducible build: 🟡 CMake with `AUTORCC` and `AUTOMOC`, a single version definition, and
  install rules; compiles cleanly with Qt 6.8.3 and the result runs. CPack is configured but
  never exercised, there is no CI, and it has been built on one machine only
- Structural verification: ✅ `make check` — 545 structural checks plus a Qt include check
- Static QML checking: 🟡 `make lint-qml` runs `qmllint` when present (verified with Qt 6.8.3)
  and exits 2 when it is absent, so a skipped check is never reported as a pass; it currently
  reports unqualified-access warnings and no errors
- Headless render check: ✅ `tahoe-shell --screenshot <file>` renders the shell once and exits,
  so a build can be checked without a display or a desktop session
- Development launcher: ✅ `launch_tahoe.sh` validates the built binary before executing it
- Automated tests for the C++ services: ⚪ only structural verification exists
- Desktop session entry: ✅ a `.desktop` file is installed by CMake
- Installer, ISO, recovery, uninstall: ⚪

## Core Applications

- Finder: ✅ (see above)
- Settings: ✅ (see above)
- Terminal, Notes, Reminders, Calendar, Photos, Preview, Text Editor, Calculator, Clock,
  Weather, Music, browser, Assistant, Activity Monitor, Archive utility, password manager,
  updater: ⚪

## Not implemented, deliberately, and labelled as such

These are the places where the shell could easily have shown something convincing and false:

- The Control Center does not show network, sound, Bluetooth, or power switches, because there
  is no backend behind them. It says what is missing instead.
- The Settings application does not offer Dock position, because only the bottom edge works.
- The menu bar does not show a search field, because Spotlight is the implemented search.
- Dock tiles show a text label rather than an invented icon when no theme icon resolves.
- Finder shows a real file extension or `DIR` rather than placeholder file-type artwork.
- The Notification Center dims its indicator and explains itself when another daemon owns
  `org.freedesktop.Notifications`, instead of showing a confident and misleading empty bell.

## Feature Status Principles

- A feature is not "done" because it looks right
- A feature is done only when it is implemented, connected, persistent where required, tested,
  and accurately reported
- Temporary mocks must be labelled and replaced before a feature is declared complete
