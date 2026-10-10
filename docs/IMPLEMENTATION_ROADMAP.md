# Project Tahoe X86 — Implementation Roadmap

- **Purpose**: Describe implementation phases and definition of done
- **Status**: Draft

## Phase 0 — Research and Specification

Objective: finish architecture, research, design tokens, feature matrix, and security model.

Deliverables:

- docs/PRODUCT_SPEC.md
- docs/ARCHITECTURE.md
- docs/DESIGN_SYSTEM.md
- docs/FEATURE_MATRIX.md
- docs/SECURITY_MODEL.md
- docs/IMPLEMENTATION_ROADMAP.md
- docs/RESEARCH_SOURCES.md

Exit criteria: documentation is sufficient to start building the smallest working shell.

## Phase 1 — Desktop Foundation

Objective: build a launchable shell with desktop, menu bar, Dock, window management integration, theme engine, and settings persistence.

Deliverables:

- Bootable-for-development shell entry
- Desktop surface with wallpaper placeholder
- Menu bar
- Dock with pinned/running apps
- Basic window chrome integration
- Theme engine with light/dark tokens
- Settings persistence

Exit criteria: the shell starts, shows the desktop, menu bar, and Dock, and survives a restart of settings.

## Phase 2 — Core Interaction

Objective: add application launching, file manager, search, notifications, Control Center, keyboard shortcuts, and virtual desktops.

Exit criteria: a user can open apps, browse files, search, and change common settings without mock behavior.

## Phase 3 — Applications

Objective: build the core native-feeling application suite and shared application framework.

Exit criteria: core apps open, close, persist state, and use the shared design system.

## Phase 4 — Accounts and Cloud

Objective: implement local profiles, secure credential storage, Google Drive integration, and the provider framework.

Exit criteria: local secrets are stored safely, Google Drive can authenticate and perform real operations, and status is honest.

## Phase 5 — Local AI

Objective: implement model discovery, local inference, assistant UI, typed tools, permissions, and optional voice.

Exit criteria: local inference can run without a remote provider, and unsafe actions are rejected.

## Phase 6 — Automation

Objective: implement the visual Shortcuts editor, action library, execution engine, triggers, and AI-assisted workflow creation.

Exit criteria: workflows execute real actions and are previewed/approved before execution.

## Phase 7 — OS Integration

Objective: add hardware-aware controls, multi-monitor behavior, accessibility, power management, and packaging.

Exit criteria: system panels reflect real capability and the package is buildable from instructions.

## Phase 8 — Installer and Release

Objective: build and test the installable image, first-run wizard, recovery process, and update strategy.

Exit criteria: there is a tested path to install and recover, with documented limitations.

## Progress report

**Last updated**: 2026-10-10, after the first successful build and run (Qt 6.8.3, Linux Mint
21.3). Updated whenever a phase changes state; the next concrete task is always at the bottom.

### Phases

- **Phase 0 (research and specification)**: done. `docs/PRODUCT_SPEC.md`, `ARCHITECTURE.md`,
  `DESIGN_SYSTEM.md`, `FEATURE_MATRIX.md`, `SECURITY_MODEL.md`, `RESEARCH_SOURCES.md`.
- **Phase 1 (desktop foundation)**: **exit criteria met and verified by a run.** The shell
  starts, draws the desktop, the menu bar, and the Dock, and its settings survive a restart
  (verified by rendering with a settings file on disk and reading the file back unchanged).
- **Phase 2 (core interaction)**: mostly done. Application launching, Finder, Spotlight,
  notifications, Control Center, and keyboard shortcuts are implemented. Virtual desktops,
  Mission Control, and window snapping are not.
- **Phases 3-8**: not started beyond scaffolding (CMake/CPack packaging metadata).

### Working integrations, observed on this machine

- `.desktop` scanning and launching: 152 entries found; `AppRegistry` reports `Started`,
  `NotFound`, or `Failed` and never reports success for a failed start.
- Freedesktop icon theme lookup: resolves icons across the standard contexts and the active
  theme; returns empty rather than an invented icon.
- XDG settings persistence: `$XDG_CONFIG_HOME/project-tahoe/shell/settings.json`, atomic write,
  verified to round-trip.
- The freedesktop trash specification, the real filesystem, and the session D-Bus name for
  notifications.

### Unresolved blockers

1. No permissions request path: anything privileged (network, sound, Bluetooth, power) still has
   no Polkit-backed service, which is why the Control Center shows no switches for them.
2. `org.freedesktop.Notifications` is owned by the desktop's own daemon in a normal session, so
   the shell cannot receive other applications' notifications while a full desktop is running.
   Receiving them needs a session where the shell owns the name.
3. The PySide6 development launcher (`tahoe_py.py`) cannot load the QML on PySide6 6.12.0; the
   same QML runs correctly under Qt 6.8.3 C++. Not on the critical path, but it should either be
   fixed or removed.
4. Nothing is verified on Wayland or on multi-monitor hardware, which the shell's display-aware
   placement and Dock behaviour both depend on.

### Next concrete tasks, in order

1. Application menus in the menu bar, driven by the active application (the largest visible gap
   in the shell chrome, and the one that makes the shell feel unfinished).
2. Window geometry persistence, so window positions and sizes survive a restart.
3. Desktop icons, selection, and context menus on the desktop surface.
4. Virtual desktops plus a Mission Control-style overview, which needs a compositor-side story
   before the UI is worth writing.
5. A first Polkit-backed system service (starting with display brightness or network state), so
   the Control Center can show real controls instead of naming the gap.

## Definition of Done

A feature is complete only when:

- Its implementation exists
- Its UI is connected to real implementation
- Its state persists where required
- Errors are handled
- Permissions are enforced
- Tests have been run
- Relevant documentation exists
- Its status is accurately reported

