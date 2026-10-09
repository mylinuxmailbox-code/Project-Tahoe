# Packaging — Project Tahoe X86

This directory is the packaging assembly workspace for the shell deliverable.

It is intentionally separate from the shell source tree so packaging, metadata,
installer prep, and verification notes do not leak into the core build files.

## What belongs here

- Packaging metadata and templates
- Installer prep artifacts
- Bundle/dependency notes
- Verification checklists for release readiness

## Current status

- CMake/CPack packaging scaffold exists.
- Windows installer skeleton exists as a prep note only.
- Release verification checklist exists.
- No generated package has been produced here yet.

## Packaging rules

- Package metadata must match the build target name and version in the shell CMake target.
- Installer artifacts must be clearly labeled as optional or platform-specific.
- Packaging notes must distinguish verified behavior from planned behavior.
- No secrets, credentials, or user-specific tokens may appear in packaging artifacts.

## Assembly order

1. Confirm the shell builds and the binary target name is `tahoe-shell`.
2. Confirm the installer/packaging metadata references the correct version.
3. Run the release verification checklist.
4. Produce a package only after the checklist passes.

## Deliverable notes

- Linux distribution packaging can use CPack-style workflows where appropriate.
- Cross-platform installer prep is allowed as a separate artifact, but it must not
  claim to be the production installer until it has been generated and tested.
