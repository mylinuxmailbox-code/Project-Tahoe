# Project Tahoe X86 — Build Environment

- **Purpose**: What the shell needs to build, how to build it, what has actually been verified,
  and what is still unverified
- **Status**: Current as of the first successful build and run

## Honest status summary

**The shell compiles and runs.** This was verified on 2026-10-10 on Linux Mint 21.3
(Ubuntu 22.04 base), x86-64, with Qt 6.8.3 installed through `aqtinstall` (no distribution Qt 6
packages were installed, and no package-manager password was available).

Before this build the project had never been compiled, and the first build did surface real
defects — they are listed under "Defects found by the first build" below. Everything now
reported as working was observed in a run, not inferred from the source tree.

Verified facts, with the evidence:

| Claim | Evidence |
|---|---|
| The C++ shell builds | `cmake --build build` exits 0 and produces `build/bin/tahoe-shell` |
| The shell starts and loads its QML | `./build/bin/tahoe-shell` runs; no QML errors or warnings on stderr |
| The application registry works | startup line reports `152 applications found` from the real `.desktop` files on this machine |
| The shell renders | `--screenshot` writes a 1280x800 PNG; the pixels match the design tokens (see "Verification performed") |
| It runs on a real display, not only offscreen | `DISPLAY=:0 ./build/bin/tahoe-shell --screenshot ...` renders through the real X11/OpenGL path |
| Preferences persist and are re-applied | with `XDG_CONFIG_HOME` pointing at a config file set to `light`, the shell renders light (mean brightness 91% vs 6% dark) and rewrites the file byte-for-byte the same |

Structural verification (`make check`, 545 checks) passes as well, but it is not what makes the
claims above true: the run is.

## Requirements

| Requirement | Version | Notes |
|---|---|---|
| Qt | 6.2 or newer | Components: Core, Gui, Qml, Quick, DBus. Verified with 6.8.3 |
| Qt D-Bus | same version | Optional. Without it the shell still builds, but it cannot receive notifications from other applications, and says so |
| Qt Quick Controls | 2 | Required at runtime by the shell window (`ApplicationWindow`, `header`). In Qt 6 it ships in the `qtdeclarative` archive/package, not separately |
| libxcb-cursor | any | **Required since Qt 6.5** for the `xcb` platform plugin. Without it the shell only runs offscreen. See "System libraries Qt needs" |
| ICU | 73 for the official Qt 6.8 binaries | The official Linux binaries link `libicuuc.so.73`. Distributions older than Ubuntu 23.10 ship ICU 70 or 72. See "System libraries Qt needs" |
| CMake | 3.22 or newer | The root `CMakeLists.txt` requires 3.22 |
| Compiler | C++17 | GCC 9+ or Clang 10+ |
| qmllint | optional | Only for `make lint-qml` |

## Building

### Option A — distribution packages (simplest, where Qt 6 packages exist)

On Debian or Ubuntu 22.04-class systems:

```bash
sudo apt-get update
sudo apt-get install -y cmake g++ qt6-base-dev qt6-declarative-dev \
  qt6-declarative-dev-tools qml6-module-qtquick qml6-module-qtquick-window \
  qml6-module-qtquick-controls qml6-module-qtqml libxcb-cursor0
```

Distribution Qt on Ubuntu 22.04 is 6.2, which is the minimum this project supports.

### Option B — a Qt toolchain in a directory, no root required

This is how the verified build on this machine was produced:

```bash
pip install aqtinstall
python3 -m aqt install-qt linux desktop 6.8.3 linux_gcc_64 \
  --archives qtbase qtdeclarative qtsvg --outputdir "$HOME/Qt"
```

Then configure against it:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH="$HOME/Qt/6.8.3/gcc_64"
cmake --build build -j"$(nproc)"
./build/bin/tahoe-shell            # or: ./launch_tahoe.sh
```

### Build and run as your normal user, not as root

Running the shell as root would make `SettingsStore` write to `/root/.config/project-tahoe/...`
instead of your own configuration, which looks exactly like broken persistence. Installing
packages as root is of course fine.

### System libraries Qt needs

The official Qt 6.8 Linux binaries need two system libraries that an older base distribution
does not provide. Neither is a problem with distribution Qt packages; both apply to the
`aqtinstall` route.

1. **ICU 73.** Qt's official binaries link `libicuuc.so.73`, `libicui18n.so.73`, and
   `libicudata.so.73`. Mint 21.3 ships ICU 70, and `rcc` fails with
   `error while loading shared libraries: libicui18n.so.73`, which stops the build inside the
   resource step. Provide ICU 73 on the loader path — either install a package that provides it,
   or place the three libraries in the Qt install's own `lib/` directory, where the Qt binaries
   find them through their `$ORIGIN` RPATH.
2. **libxcb-cursor0.** Qt 6.5 and newer refuse to load the `xcb` platform plugin without it
   (`qt.qpa.plugin: From 6.5.0, xcb-cursor0 or libxcb-cursor0 is needed`). It can be obtained
   without root:

   ```bash
   cd /tmp && apt-get download libxcb-cursor0 && dpkg-deb -x libxcb-cursor0_*.deb /tmp/xcbcursor
   cp /tmp/xcbcursor/usr/lib/x86_64-linux-gnu/libxcb-cursor.so.0* \
      "$HOME/Qt/6.8.3/gcc_64/lib/"
   ```

### If a package manager in your PATH shadows the system linker

If a Homebrew or conda `ld` comes before `/usr/bin` in `PATH`, linking fails with hundreds of
`undefined reference to 'FcPatternAdd'`-style errors, because that linker does not search the
system library directories. Build with the system tools first on `PATH`:

```bash
PATH=/usr/bin:/bin:$PATH cmake --build build -j"$(nproc)"
```

## Verification performed

```bash
# 1. Headless render, and a check that the QML loads without warnings
env -u DISPLAY QT_QPA_PLATFORM=offscreen ./build/bin/tahoe-shell --screenshot /tmp/dark.png
#   -> "--screenshot: wrote /tmp/dark.png 1280 x 800", no QML diagnostics

# 2. The real display path
DISPLAY=:0 ./build/bin/tahoe-shell --screenshot /tmp/x11.png

# 3. Preferences: write a settings file, render, and read it back
XDG_CONFIG_HOME=/tmp/tahoe-cfg ./build/bin/tahoe-shell --screenshot /tmp/light.png
```

What the pixels showed, checked against `src/shared/tokens/DesignTokens.qml`:

- Dark mode: menu-bar pixel `rgb(11,13,15)` = `#0b0d0f` = `bgPanel` for the dark palette.
- Light mode from the settings file: menu-bar pixel `rgb(247,248,250)` = `#f7f8fa` = `bgPanel`
  for the light palette, and the whole-frame mean brightness moved from 6% to 91%. That is the
  preference being read from disk and applied, not a default.
- The Dock rendered two tiles with real icons resolved from the system icon theme, and fell back
  to the item's label where no icon exists.
- The settings file was rewritten with identical content after the run, so load → apply → save
  round-trips without loss.

Screenshots from these runs are committed under `docs/screenshots/`.

## Defects found by the first build

The first compile and run found these real problems, all fixed:

1. `AppRegistry` derived from `QObject` while using the `QAbstractListModel` API
   (`rowCount`/`data`/`roleNames` with `override`, and `beginResetModel`), so it did not compile.
2. `FileService::collectMatches` called `QDirIterator::setFollowSymlinks(false)`, which does not
   exist in Qt. Not following symlinks is the default; the call was removed. The structural
   checker asserted that non-existent call, so it had been passing on code that could not
   compile — the check now asserts the real requirement (that `QDirIterator::FollowSymlinks` is
   not set).
3. `TahoeNotificationCenter` had a genuine binding loop on the panel `height`: it read
   `listArea.height` while `listArea` was anchored to the panel's own bottom edge. It now sizes
   from the list's `contentHeight`, with a floor.
4. The Dock showed placeholder labels instead of icons, and its tiles used the panel colour on a
   panel-coloured surface, so they were nearly invisible. Tiles now render the resolved icon
   (label as fallback) on `bgRaised`.
5. Icon resolution only looked in the `apps` context of four hardcoded themes, so an icon such as
   `preferences-system` (a `categories` icon) was never found. It now searches all standard
   contexts and prefers the active theme from `QIcon::themeName()`, with the previous list kept
   as fallback.
6. A resolved icon path was passed to QML's `Image` as a filesystem path, so it was resolved
   against the QML file's own URL and failed to load. Absolute paths are now converted to file
   URLs at the point where the shell builds the Dock item.

## Known issues and gaps

- **The PySide6 development launcher does not work in this environment.** `tahoe_py.py` loads the
  same QML against PySide6; with PySide6 6.12.0 the QML components fail to instantiate whenever a
  service singleton is registered via `qmlRegisterSingletonInstance` (`Cannot assign object of
  type "QQmlTimer" to list property "data"`). The same QML loads and runs correctly under Qt
  6.8.3 C++, including on this machine, and the failure reproduces in a minimal 20-line case, so
  it is a binding-layer problem rather than a defect in this project's QML. The file is kept
  because it is useful on other Qt builds, and it is **not** a supported path until it is fixed.
- `make lint-qml` now runs for real and reports warnings: unqualified access to `model` inside
  `ListView` delegates, and to the service singletons (which `qmllint` cannot see because they
  are registered from C++). No errors. These are worth cleaning up, and none of them is known to
  affect the running shell.
- `org.freedesktop.Notifications` is owned by the desktop's own notification daemon on this
  machine, so the shell correctly reports that it cannot receive other applications'
  notifications here. The server path itself was not exercised in this environment.
- Nothing has been verified on Wayland, on a multi-monitor setup, or on hardware other than the
  machine described above. Window geometry persistence, desktop icons, virtual desktops, and
  Mission Control are not implemented (see `docs/FEATURE_MATRIX.md`).
- Windows and macOS are not supported: the services use XDG directories and the freedesktop
  trash specification directly.

## What the build produces

- `build/bin/tahoe-shell` — the shell, with all QML compiled into the binary through `AUTORCC`,
  so it does not depend on the source tree at runtime
- An installed `share/applications/org.projecttahoe.shell.desktop`
- A CPack package target, configured but not yet exercised

## First-run checklist

1. The window opens with the desktop, menu bar, and Dock.
2. The menu bar reports the registry scan result (`N applications found`). A count of zero on a
   desktop system means the `.desktop` scan is broken, not that nothing is installed.
3. `Ctrl+Space` opens Spotlight and typing part of an application name lists real applications.
4. Clicking a Dock icon opens Finder or Settings as a real window. Dragging its title bar moves
   it, and dragging its edges resizes it.
5. In the Settings application, switch to light mode: the whole shell re-colours. Quit and
   restart, and the mode persists.
6. In Finder, create a folder, rename it, move it to the Trash, then restore it.
7. The menu bar's notification indicator: if it reads dimmed, another notification daemon owns
   `org.freedesktop.Notifications`, and the Notification Center says so.
