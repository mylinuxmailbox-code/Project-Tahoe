# Release Verification Checklist — Project Tahoe X86

Run before producing any package, installer, or release artifact.
Automated part: `make check` (tools/verify_structure.py). The manual items below cannot be
automated on a machine without a Qt 6 build environment.

## Automated (make check)

- [ ] `make check` exits 0 (structural verification)
- [ ] Required files exist and are non-empty
- [ ] Every file referenced by `src/shell/tahoe.qrc` exists on disk
- [ ] Every relative QML import resolves to a directory with a valid `qmldir`
- [ ] `src/shared/tokens/qmldir` declares the `DesignTokens` singleton
- [ ] `main.qml` imports the shared modules and binds the Dock to real settings
- [ ] `TahoeDock.qml` exposes the model API and wires tile activation
- [ ] `src/services/tahoe_shell.json` is valid JSON covering the required states
- [ ] CMake wiring present: `AUTORCC`, `TAHOE_VERSION` define, install rules, CPack
- [ ] Version strings consistent (CMake project version vs packaging note)
- [ ] No credential-style assignments in packaging artifacts

## Static QML (make lint-qml)

- [ ] `qmllint` reports no warnings or errors
- [ ] If `qmllint` is unavailable, this item is recorded as SKIPPED, never as passed
      (currently SKIPPED on the development machine — `qt6-declarative-dev-tools` absent)

## Build readiness (manual, requires Qt 6)

- [ ] CMake configuration succeeds against the intended Qt 6 environment
- [ ] `tahoe-shell` compiles and links
- [ ] The binary starts and loads `qrc:/shell/qml/main.qml` with no QML errors
- [ ] `README.md` and `build_env.md` match the environment actually used
- [ ] Version shown by the running shell matches the CMake project version

## Runtime behavior (manual, requires Qt 6)

- [ ] Dock renders pinned items and reflects `runningItems` indicators
- [ ] Tile activation emits and is handled
- [ ] Magnification and auto-hide behave as documented (and as limited in the matrix)
- [ ] Settings values are read from the settings model by the Dock
- [ ] Preferences survive a restart (settings.json written under the XDG config path)
- [ ] A deliberately corrupted settings.json is reported as "defaults in use" and left unmodified
- [ ] Dock activation of an app with no installed launcher reports NotFound, not a false success
- [ ] No control in the UI is decorative: each does something real or states it is unavailable

## Package readiness

- [ ] Packaging rules in `packaging/README.md` are followed
- [ ] Any installer or package artifact states its platform and status
- [ ] Release notes distinguish implemented, partially implemented, and planned features
- [ ] Known limitations documented in `docs/FEATURE_MATRIX.md` and `build_env.md`
- [ ] An artifact is produced only after the build and runtime items above are satisfied
