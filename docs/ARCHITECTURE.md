# Project Tahoe X86 — Architecture

- **Purpose**: Document the entire system architecture
- **Status**: Draft

## 1. System Boundaries

Project Tahoe X86 is a custom desktop shell and application layer running on top of Linux.

It does **not** replace:

- The Linux kernel
- The display server / compositor except where we explicitly wrap or coordinate with it
- Linux system accounts or PAM for OS login
- The host boot chain

It **does** provide:

- A Qt/QML desktop shell with menu bar, Dock, desktop, window chrome, and system panels
- Shared design tokens and components
- Services for app launching, files, settings, notifications, search, cloud, AI, and shortcuts
- Core desktop applications

## 2. Target Stack

- **Base OS**: Linux, starting from common Ubuntu/Mint-class x86-64 environments
- **Display protocol**: Wayland where available; X11-supported fallbacks where needed
- **Window manager/compositor integration**: Native X11/Wayland APIs plus KWin/pluggable compositor services where they exist
- **UI**: Qt 6 + QML for the shell and apps
- **Native services**: C++ for performance-sensitive platform glue; Python where it speeds development
- **Local database**: SQLite for indexing, shortcuts, notes, settings cache, and app data
- **Secrets**: Secret Service / libsecret-compatible keyring for OAuth tokens and sensitive credentials
- **IPC**: D-Bus for system services and local daemon communication
- **Build system**: CMake where C++ is involved; scripted launchers for the shell

## 3. Architectural Layers

### A. Desktop shell and UI

- Main shell window manager for splash, desktop, menu bar, Dock, and panels
- QML-based shared components: buttons, panels, sheets, cards, list items, dialogs, toggles, pickers
- Theme engine mapping design tokens to Qt palettes, fonts, radii, shadow, opacity, and animation values

### B. Window and display management

- Query and control active window state through platform APIs where available
- Report window positions, workspace/virtual desktop state, full-screen state, and focus
- Coordinate with compositor for animations, stacking, snapping, full-screen behavior

### C. System integration services

- Application launching via desktop environment / session APIs
- Filesystem access through the real filesystem and XDG directories
- Audio, Bluetooth, networking, power, display, and removable storage queries through system services
- Notifications through desktop notification APIs

### D. Applications

- Shared application shell and menu model
- Per-app QML/C++ implementations using the same tokens and components

### E. Local AI services

- Provider abstraction over Ollama and llama.cpp-compatible runtimes
- Typed tool registry for assistant actions
- Permission-checked execution layer

### F. Cloud and identity connectors

- Provider interface with a local-files provider and Google Drive provider
- OAuth 2.0 native-app flow for Google
- Secure token storage
- iCloud supported only where beneficial, honest, and technically justified

### G. Settings, configuration, and persistence

- XDG-based config layout
- Versioned JSON/QSettings or similar preference storage
- SQLite for search indexes, shortcut definitions, and some app data

### H. Testing, installation, recovery, and updates

- Automated unit and integration tests
- Packaging scripts and a launcher target
- First-run workflow and update/recovery documentation

## 4. Component Model

Every system capability should be accessed through a service interface, not through ad hoc script parsing.

General service states:

- Available
- Unavailable
- Loading
- Running
- Completed
- Failed
- Requires permission
- Requires configuration

## 5. Design Decisions and Rationale

- **Linux base, not a custom bootable distro initially**: faster iteration and safer testing on the current machine
- **Qt 6 / QML UI**: necessary for translucent panels, custom chrome, and a cohesive app framework
- **Local AI by default**: matches the requirement that cloud AI is opt-in and consent-based
- **Provider-based cloud layer**: avoids baking a single cloud vendor into the shell
- **Secret Service for credentials**: avoids storing tokens in plain config files
- **Quickshell-style QtQuick shell mindset**: useful reference for panels/widgets, but this project is its own shell, not necessarily a Quickshell config

## 6. Known Trade-offs

- Liquid Glass effects on Linux depend on the platform; we may approximate with layered transparency and blur where real time rendering is available, and degrade gracefully otherwise
- iCloud support is limited by the lack of a general-purpose public third-party iCloud Drive API suitable for a desktop shell; we will not pretend otherwise
- Some macOS workflows depend on proprietary Apple services; we replicate the workflow pattern, not the proprietary service

