# Qt Deployment Notes — Project Tahoe X86

This document records deployment considerations for the Tahoe shell on Linux.

## Target environment

- x86-64 Linux
- Qt 6 with QML
- Wayland preferred where available
- X11 fallback where required

## Build-to-run relationship

- The shell is built from `src/shell/CMakeLists.txt`.
- The expected output name is `tahoe-shell`; the development launcher expects
  `build/bin/tahoe-shell`.
- QML is compiled into the binary via `src/shell/tahoe.qrc` (`AUTORCC ON`). The bundle
  mirrors the source tree, so `qrc:/shell/qml/main.qml` and its relative imports into
  `/shared/tokens`, `/shared/components`, and `/services` resolve without any disk paths.
- The application version comes from `project()` in the root `CMakeLists.txt`, passed as
  the `TAHOE_VERSION` compile definition.

## Runtime QML dependencies

On Debian/Ubuntu-class systems the host needs the QML runtime modules the shell imports:

- `qml6-module-qtquick`
- `qml6-module-qtquick-window`
- `qml6-module-qtquick-controls`
- `qml6-module-qtquick-templates` (pulled in by Controls)
- `qml6-module-qtqml`

Development files (`qt6-base-dev`, `qt6-declarative-dev`) are only needed to build, not to run.

## Deployment principles

- Keep the shell separate from the host session until a real packaging step is ready.
- Do not assume a specific compositor, desktop environment, or display server beyond
  what the target machine actually provides.
- Degrade gracefully when advanced effects such as blur or transparency are unavailable.
- Do not ship the shell as if it were a full operating system installer unless an
  installable image has been built and tested.

## Bundle considerations

- The `.qrc` is the only QML source of truth at runtime; do not add disk-path fallbacks.
- If new QML files are added to `/shared` or `/services`, add them to `tahoe.qrc` and to the
  relevant `qmldir`, or the import will fail at startup. `make check` verifies this.
- Any shared assets, icons, or fonts should be installed through a packaging manifest,
  not by hardcoding absolute paths throughout the application.

## Platform-specific notes

- Liquid Glass-style effects are a visual target, not a guaranteed rendering feature.
- Some system integrations depend on the installed platform services and may report
  unavailable or require configuration rather than pretending to work.
- Credential storage should rely on Secret Service where available and report the
  dependency honestly.

## What this document is not

- This is not a substitute for a tested installer.
- This is not a claim that the shell can replace the host OS.
- This is not packaging output; it is deployment guidance for when packaging is ready.
