# Project Tahoe X86 v0.1 Release Checklist

This checklist is honest about what v0.1 is: a development shell that builds and runs on one
machine. It is not an installer, an ISO, or a daily-driver desktop. Tick an item only when the
evidence exists. A skipped check is recorded as skipped, never as passed.

## 1. Build

- [ ] `make verify-deps` passes on a clean Qt 6 install (record the Qt version and distro)
- [x] `make build` succeeds on Linux Mint 21.3, x86-64, Qt 6.8.3 (verified 2026-10-10, see `build_env.md`)
- [ ] `make build` re-verified on a second machine or a clean container
- [ ] Build from the tagged commit, not a working tree with local changes
- [ ] CPack package produced (configured, never exercised)

## 2. Automated checks

- [x] `make check` passes (structural only; it is not evidence that features work)
- [ ] `make test` passes: 9 service tests, run after the window geometry and Finder changes
- [ ] `make lint-qml` run and reviewed (known warnings: unqualified `model` and service singleton access)
- [ ] Failures and skips listed in the release notes

## 3. Manual smoke test (on a real display)

- [x] Shell starts and renders, no QML errors on stderr (build_env.md)
- [x] Light and dark mode persist across restart (build_env.md)
- [ ] Window geometry: move and resize Finder, quit, reopen, same place (new in this release, untested)
- [ ] Finder: New Folder, Rename, Trash, Restore, Empty Trash
- [ ] Finder: Duplicate, Copy, Cut, Paste, and the name-clash error (new, untested)
- [ ] Finder: Ctrl+C/X/V/D shortcuts work and do not fire while renaming
- [ ] Spotlight (Ctrl+Space) returns real applications and settings
- [ ] Dock: launch, activate, minimise, pin
- [ ] Notification Center: behaves honestly when another daemon owns the bus name
- [ ] Settings change survives restart

## 4. Known limitations to state in the release notes

- Network, sound, Bluetooth, and power controls are not implemented (shown as unavailable)
- Desktop icons, app menus in the menu bar, virtual desktops, snapping, Mission Control: not implemented
- Dock position: bottom edge only
- Only tested on X11 with one machine; Wayland and multi-monitor are unverified
- The PySide6 launcher (`tahoe_py.py`) does not work with PySide6 6.12.0; not a supported path
- No CI; no automated QML tests
- Notifications server path not exercised on the test machine
- Applications, cloud, local AI, Shortcuts, installer: not started

## 5. Security and packaging

- [ ] Dependency list reviewed against `docs/SECURITY_MODEL.md`
- [ ] No secrets in the repository or in logs (grep the tree for tokens before tagging)
- [ ] Release artifacts checksummed (SHA-256 recorded in the release notes)
- [ ] Release artifacts not signed (state this explicitly unless signing is added)

## 6. Documentation

- [ ] `docs/FEATURE_MATRIX.md` updated: window geometry and Finder copy/move/paste rows changed from planned to implemented-but-untested
- [ ] `build_env.md` updated with the build and test results for this release
- [ ] `README.md` status section matches the matrix
- [ ] `docs/IMPLEMENTATION_ROADMAP.md` reflects what is done

## 7. Tagging

- [ ] Every item above is ticked or listed under known limitations
- [ ] Tag `v0.1` created on the reviewed commit, annotated, with the checklist results in the message
- [ ] Release notes published with the known limitations section copied verbatim

## Sign-off

- Built by: 
- Build machine and Qt version: 
- Commit: 
- Date: 
- Open blockers: 
