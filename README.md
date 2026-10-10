# Project Tahoe X86

A custom desktop shell and application layer for Linux, built on Qt 6 and QML, aiming for a
macOS-like desktop experience implemented with real behaviour rather than mock-ups.

- **Status**: Phase 1 (desktop foundation) and most of Phase 2 (core interaction) are
  implemented, and the shell **builds and runs**: verified with Qt 6.8.3 both headless and on a
  real X11 display, including reading and re-writing its settings file. See `build_env.md` for
  what was verified and how to reproduce it, and `docs/FEATURE_MATRIX.md` for what is not
  implemented.
- **Screenshots**: `docs/screenshots/shell-dark.png`, `docs/screenshots/shell-light.png`
- **Licence**: see the notes at the end of this file.

## What works today

Shell:

- Desktop surface with a wallpaper (or a gradient when none is set), reporting real load errors
- Menu bar with the active application, a live clock, a notification indicator with the real
  unread count, and a Control Center button
- Dock with pinned and running items, icons resolved from the system icon theme (falling back
  to the item's label when no icon exists), hover magnification, auto-hide with a reveal strip,
  and real launching
- Window layer: drag, eight resize handles with minimum sizes, focus follows click, stacking,
  minimise, zoom, and close for the applications the shell hosts
- Spotlight (`Ctrl+Space`): unified search over installed applications, real files, and
  settings, keyboard driven
- Control Center: appearance, reduce motion, Dock icon size, magnification, auto-hide
- Notification Center: the real notification list, with dismissal and clearing
- Light and dark themes driven by one token module
- Keyboard shortcuts: `Ctrl+Space` Spotlight, `Ctrl+,` Settings, `Escape` to dismiss panels

Applications the shell hosts:

- **Finder**: browse, navigate with history, create folders, rename, move to the freedesktop
  trash, restore from the trash, empty the trash, show hidden files, and open files with the
  system default handler
- **Settings**: appearance, wallpaper, Dock, window chrome, notification status, and the
  settings file location

Services (C++):

| Service | Responsibility |
|---|---|
| `SettingsStore` | Atomic read/write of `$XDG_CONFIG_HOME/project-tahoe/shell/settings.json` |
| `AppRegistry` | Scans real `.desktop` entries; launches them and reports `Started` / `NotFound` / `Failed` |
| `FileService` | Directory listing, XDG locations, create, rename, copy, move, permanent removal, recursive search |
| `TrashService` | The freedesktop trash specification: `Trash/files` plus `Trash/info/*.trashinfo`, restore and empty |
| `NotificationService` | The notification model, and the session `org.freedesktop.Notifications` server when the bus name is free |
| `SearchService` | Spotlight results from the registry, the filesystem, and the settings the shell can really change |

## What is not implemented

Stated plainly, because a shell that pretends is worse than one that is incomplete:

- Network, sound, Bluetooth, and power controls. The Control Center says so rather than showing
  dead switches.
- Application menus in the menu bar (File/Edit/View driven by the active application)
- Desktop icons, drag and drop on the desktop, Quick Look previews
- Virtual desktops, Mission Control, window snapping, and full-screen handling
- Dock position other than the bottom edge
- Cloud accounts, local AI, automation, installer, and packaging beyond CMake/CPack scaffolding
- Everything in Phases 3-8 of `docs/IMPLEMENTATION_ROADMAP.md`

## Layout

```
src/shell/            shell entry point, QML surface, resource bundle, deployment notes
src/apps/             applications the shell hosts (finder, settings)
src/shared/tokens/    design tokens (single source of truth for colour, spacing, motion)
src/shared/components/ shell components: desktop, menu bar, dock, windows, panels, controls
src/services/         C++ services and the shared Settings singleton
tests/                behavioural tests for the C++ services (Qt Test, run by `make test`)
tools/               verification tools that run without Qt
docs/                specification, architecture, roadmap, feature matrix, security model
packaging/           packaging metadata and release checklist
```

## Building

Requirements: Qt 6.2 or newer (Core, Gui, Qml, Quick, and optionally DBus), CMake 3.22+, and
a C++17 compiler. On Debian or Ubuntu-class systems:

```bash
sudo apt-get install cmake g++ qt6-base-dev qt6-declarative-dev \
  qt6-declarative-dev-tools qml6-module-qtquick qml6-module-qtquick-window \
  qml6-module-qtquick-controls qml6-module-qtqml
```

Then build and run **as your normal user**, not as root (running as root would write the
settings file to `/root/.config` instead of your own):

```bash
make verify-deps
make build
./build/bin/tahoe-shell        # or: ./launch_tahoe.sh
```

Without a distribution Qt 6 package, `aqtinstall` into a directory works too (and is how the
verified build was made); `build_env.md` has that route, plus the two system libraries Qt's
official Linux binaries need. To check a build without a display, the shell can render itself
once and exit:

```bash
QT_QPA_PLATFORM=offscreen ./build/bin/tahoe-shell --screenshot /tmp/shell.png
```

## Verification

```bash
make test         # builds, then runs the C++ service tests through ctest
make check        # structural checks + a Qt include check; no Qt needed
make lint-qml     # qmllint; exits 2 when qmllint is absent, so a skip is not a pass
```

`make test` is the behavioural one: it calls the real `SettingsStore`, `FileService`,
`NotificationService`, and `AppRegistry` and checks their documented contracts, including the
ones about honesty — a missing settings file is defaults in use and not an error, a broken one is
reported and left untouched, and a failed file operation carries a real error string. The tests
run without a desktop session and never touch your own configuration or files.

`make check` proves the source tree is internally consistent. It does not compile or run
anything, and it is not a substitute for a build — the first real build of this project found
six defects that `make check` had been reporting as passing. See `build_env.md` for the build
and run verification, and `CONTRIBUTING.md` for the rules that keep the project honest.

## Licence

See the licence notes in `README.md` history and `docs/` for third-party attributions. Qt is
used under its own licence terms; no Qt source is vendored in this repository.
