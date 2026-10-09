# Project Tahoe X86 — Build Environment

- **Purpose**: What the shell needs to build, how to build it, and what is unverified
- **Status**: Current as of the Phase 2 implementation

## Honest status summary

**This project has never been compiled or run.** It was written on a machine where a Qt 6
development environment was not available:

- `qt6-base-dev`, `qt6-declarative-dev`, and `qml6-module-qtquick*` all exist in that
  distribution's repositories, but installing them requires a package manager password that
  was not available.
- `cmake -S . -B build` therefore stops at `find_package(Qt6)` with
  `Qt6Config.cmake` not found.

Everything verified so far is structural (`make check`), not behavioural. Expect the first
build to surface compile errors; they have not had a chance to be caught yet.

## Requirements

| Requirement | Version | Notes |
|---|---|---|
| Qt | 6.2 or newer | Components: Core, Gui, Qml, Quick |
| Qt D-Bus | same version | Optional. Without it the shell still builds, but it cannot receive notifications from other applications, and says so |
| CMake | 3.16 or newer | |
| Compiler | C++17 | GCC 9+ or Clang 10+ |
| Qt Quick Controls | 2 | Required at runtime by the shell window (`ApplicationWindow`, `header`) |
| qmllint | optional | Only for `make lint-qml` |

On Debian or Ubuntu-class systems:

```bash
sudo apt-get update
sudo apt-get install -y cmake g++ qt6-base-dev qt6-declarative-dev \
  qt6-declarative-dev-tools qml6-module-qtquick qml6-module-qtquick-window \
  qml6-module-qtquick-controls qml6-module-qtquick-templates qml6-module-qtqml
```

`qt6-base-dev` provides the DBus module. `qt6-declarative-dev` provides the QML engine and the
Qt Quick Controls runtime modules that `ApplicationWindow` comes from.

## Build and run

Build and run **as your normal user**, not as root. Running the shell as root would make
`SettingsStore` write to `/root/.config/project-tahoe/shell/settings.json` instead of your own
configuration, which looks exactly like broken persistence. Installing packages as root is of
course fine.

```bash
make verify-deps                                  # check cmake, g++, and the Qt 6 config
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --target tahoe-shell -j"$(nproc)"
./build/bin/tahoe-shell                           # or: ./launch_tahoe.sh
```

`make build` runs the configure and build steps together.

To install into a prefix:

```bash
cmake --install build --prefix ~/.local
```

## What the build produces

- `build/bin/tahoe-shell` — the shell, with all QML compiled into the binary through
  `AUTORCC`, so it does not depend on the source tree at runtime
- An installed `share/applications/org.projecttahoe.shell.desktop`
- A CPack package target, configured but never exercised

## First-run checklist

When it does build, these are the things to check, in order:

1. The window opens with the desktop, menu bar, and Dock.
2. The menu bar reports the application registry scan result (`N applications found`). A count
   of zero on a desktop system means the `.desktop` scan is broken, not that nothing is
   installed.
3. `Ctrl+Space` opens Spotlight and typing part of an application name lists real applications.
4. Clicking a Dock icon opens Finder or Settings as a real window. Dragging its title bar moves
   it, and dragging its edges resizes it.
5. In the Settings application, switching to light mode re-colours the whole shell, then quit
   and restart — the mode should persist.
6. In Finder, create a folder, rename it, move it to the Trash, then restore it.
7. The menu bar's notification indicator: if it reads dimmed, another notification daemon owns
   `org.freedesktop.Notifications` and the Notification Center will say so.

## Known environment gaps

- No Qt 6 toolchain where this was written, so compilation is unverified.
- `make lint-qml` cannot run without `qmllint`, and reports the skip as exit code 2 rather than
  pretending the QML was checked.
- Windows and macOS are not supported: the services use XDG directories and the freedesktop
  trash specification directly.
