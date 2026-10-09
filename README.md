# Project Tahoe X86

A custom desktop shell and application layer for Linux, built on Qt 6 and QML, aiming for a
macOS-like desktop experience implemented with real behaviour rather than mock-ups.

- **Status**: Phase 1 (desktop foundation) and most of Phase 2 (core interaction) are
  implemented. Nothing has been compiled or run yet, because no Qt 6 development environment
  was available where the code was written. See `build_env.md` for the exact situation.
- **Licence**: see the notes at the end of this file.

## What works today

Shell:

- Desktop surface with a wallpaper (or a gradient when none is set), reporting real load errors
- Menu bar with the active application, a live clock, a notification indicator with the real
  unread count, and a Control Center button
- Dock with pinned and running items, hover magnification, auto-hide with a reveal strip, and
  real launching
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
tools/               verification tools that run without Qt
docs/                specification, architecture, roadmap, feature matrix, security model
packaging/           packaging metadata and release checklist
```

## Building

Requirements: Qt 6.2 or newer (Core, Gui, Qml, Quick, and optionally DBus), CMake 3.16+, and
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

## Verification

```bash
make check        # structural checks + a Qt include check; no Qt needed
make lint-qml     # qmllint; exits 2 when qmllint is absent, so a skip is not a pass
```

`make check` proves the source tree is internally consistent. It does not compile or run
anything, and it is not a substitute for a build. See `CONTRIBUTING.md` for the rules that
keep the project honest.

## Licence

See the licence notes in `README.md` history and `docs/` for third-party attributions. Qt is
used under its own licence terms; no Qt source is vendored in this repository.
