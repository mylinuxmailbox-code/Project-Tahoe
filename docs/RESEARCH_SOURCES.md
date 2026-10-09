# Project Tahoe X86 — Research Sources

- **Purpose**: Record research sources, what they establish, and decisions
- **Status**: Draft

## 1. Apple — New software design

- URL: https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/
- What it establishes: Liquid Glass is the new cross-platform design material for iOS 26, iPadOS 26, macOS Tahoe 26, watchOS 26, and tvOS 26, with translucent surfaces, dynamic reactions, and controls refactored as a functional layer above content
- Decision: use Liquid Glass as the visual reference, but implement an original approximation on Linux, not an Apple-derived material

## 2. Apple — macOS Tahoe feature document

- URL: https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf
- What it establishes: feature-level detail for macOS Tahoe behavior and design emphasis
- Decision: use as reference for workflow patterns, not for proprietary services or API claims

## 3. Apple Developer macOS guidance

- URL: generic Apple Developer macOS guidance
- What it establishes: macOS interaction patterns, window and menu conventions, and system behavior vocabulary
- Decision: track conventions for menus, window chrome, search, Control Center, and Notification Center patterns

## 4. KDE and Linux desktop infrastructure

- URL: KDE project resources, ArchWiki, freedesktop.org D-Bus references
- What it establishes: Linux desktop shells rely on D-Bus, XDG portals, session services, and compositors; Wayland and X11 coexistence is common
- Decision: use D-Bus and XDG conventions for system integration; support Wayland where available and degrade on X11

## 5. Qt 6 / QML

- URL: Qt documentation and Qt blog
- What it establishes: Qt Quick/QML is viable for custom panels, translucent surfaces, and app chrome; native platform capabilities vary
- Decision: Qt 6 + QML is the UI foundation; effects must degrade gracefully when advanced rendering is unavailable

## 6. Quickshell

- URL: https://quickshell.org/ and related project pages
- What it establishes: QtQuick can be used to build status bars, widgets, lock screens, and panel-style desktop components on Linux
- Decision: treat Quickshell as a useful reference pattern for shell components, not as the project's required framework

## 7. Ollama / llama.cpp / GGUF

- URL: Ollama documentation and blog; llama.cpp repository; Hugging Face Ollama integration docs
- What it establishes: Ollama supports llama.cpp-compatible local inference and GGUF import workflows; local inference is feasible for desktop assistant use
- Decision: default to local inference via Ollama with a llama.cpp adapter; remote providers are opt-in

## 8. Google Drive API and OAuth 2.0

- URL: Google API authentication documentation; Qt OAuth blog post; Google OAuth sample repositories
- What it establishes: Google APIs require OAuth 2.0, and native desktop clients have a specific OAuth flow; Qt applications can use OAuth through standard web-based authorization
- Decision: implement Google Drive via OAuth 2.0 with a native-app authorization flow and store tokens in a keyring

## 9. iCloud

- URL: Apple service documentation and public discussions of third-party limitations
- What it establishes: general-purpose third-party access to full iCloud services is limited; iCloud Drive parity is not freely available to third-party desktop shells in the same way as within Apple's platform
- Decision: support iCloud only where beneficial and honest; do not claim full iCloud parity without verified implementation

## 10. Secret Service / libsecret

- URL: GNOME libsecret documentation and D-Bus Secret Service references
- What it establishes: Linux desktop environments expose a Secret Service API for storing and retrieving secrets, commonly backed by gnome-keyring or similar providers
- Decision: use a Secret Service-compatible keyring for OAuth tokens and sensitive credentials

## 11. Local filesystem and XDG conventions

- URL: XDG base directory specification conventions and standard Linux filesystem behavior
- What it establishes: config, cache, data, and runtime locations are standardized; real filesystem operations must respect permissions, mounts, and links
- Decision: store config and data under XDG-conventional paths and use real file operations

## Limitations and Open Questions

- Liquid Glass rendering quality on Linux depends on platform support; we may need layered transparency and blur approximations
- Some macOS workflows assume proprietary Apple services; we replicate workflows, not proprietary backends
- iCloud integration is constrained by available third-party APIs
- OAuth client registration for Google may require project setup and user-controlled consent
- KWin/Wayland integration details depend on the installed stack; we should test early on the target machine

