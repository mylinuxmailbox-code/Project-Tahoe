# Project Tahoe X86 — Product Spec

- **Project**: Project Tahoe X86
- **Host OS base**: Linux on x86-64
- **UI framework**: Qt 6 / QML
- **Default AI**: Local, via Ollama / llama.cpp-compatible inference
- **Created**: 2026-10-09
- **Status**: Draft

---

## 1. Purpose

Build a real, installable, persistent, interactive desktop environment for standard x86-64 Linux machines that reproduces the look, feel, and workflow of macOS Tahoe without requiring Apple hardware, Apple software, or an Apple account.

This is a desktop operating environment, not a web app, not a Figma mock, not a browser-based simulation.

## 2. Target Users

- Linux desktop users who want a macOS-like visual language and workflow
- Developers and tinkerers with x86-64 hardware who want a Qt-based custom shell
- Privacy-conscious users who want local AI and cloud integrations without vendor lock-in
- Users who already have Ollama, llama.cpp, or local models available

## 3. Success Criteria

- The shell launches without replacing the existing session
- The desktop, menu bar, Dock, window controls, file manager, settings, search, notifications, Control Center, assistant, and shortcuts are functional at a realistic level
- Real system APIs are used for networking, audio, Bluetooth, power, display, and application launching where supported
- Local AI works without a remote provider
- Cloud integrations communicate with real APIs and never fake success
- Settings persist across restarts
- The project remains buildable from documented, reproducible instructions

## 4. Non-Negotiable Constraints

- x86-64 target
- Linux base
- Real hardware support, with a development mode that does not replace the current desktop
- No destructive installation without explicit user authorization
- No simulated cloud, AI, or system operations presented as real
- Separate "implemented / partially implemented / planned" status for every feature

## 5. Scope Boundaries

### In scope

- Desktop shell and shared visual framework
- Dock, menu bar, window management integration, virtual desktops
- File manager, search/launcher, notifications, Control Center, System Settings
- Local account and secure credential storage
- Google Drive provider using OAuth 2.0
- Honest iCloud handling with documented limits
- Local AI assistant with typed tools and permissions
- Shortcuts-style workflow editor and execution engine
- Core application suite: Finder, Notes, Reminders, Calendar, Photos gallery, Preview, Text Editor, Terminal, Calculator, Clock, Music, Settings, Shortcuts, Assistant, Activity Monitor, Archive utility, System updater, password-manager integration, Safari-inspired browser where an engine is available
- One reproducible build path and at least one launcher

### Out of scope for the first release

- Replacing Linux boot, init, or the display server
- Full iCloud parity for Photos, Keychain, Notes, or Contacts without verified APIs
- Installing or repurposing the host OS without explicit consent
- Claiming an Apple ID or Apple ecosystem feature that we cannot actually provide

## 6. Interface Commitments

Every visible control must either do something real or clearly state that the capability is unavailable.

Services must report explicit states: Available, Unavailable, Loading, Running, Completed, Failed, Requires permission, Requires configuration.

## 7. Performance and Hardware Baseline

- 64-bit Intel or AMD
- Integrated or common discrete GPU
- 8 GB RAM practical baseline for the desktop
- 16 GB or more recommended for larger local AI workloads
- SSD preferred, 1080p or higher displays, mixed-DPI and multi-monitor where supported
- Shell must stay lightweight when AI is idle

## 8. Identity

- "Project Tahoe X86" is the project name
- "Project Tahoe Assistant" is the local assistant
- The product is visually inspired by macOS Tahoe; it is not macOS and not Apple software

