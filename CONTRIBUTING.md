# Contributing to Project Tahoe X86

## Scope

This is a desktop shell and application layer on top of Linux.

Do not contribute changes that:
- Pretend cloud, AI, or system actions succeeded when they did not
- Add decorative controls with no real behavior
- Remove or weaken security checks for convenience

## Development model

- Shell and UI are in `src/shell/`
- Shared design tokens are in `src/shared/tokens/`
- Shared components are in `src/shared/components/`
- Service contracts and stubs are in `src/services/`
- Documentation is in `docs/`
- Build notes are in `build_env.md`

## Stubs

Stubs are allowed during Phase 1, but they must be clearly labeled.

A stub should state:
- What it provides
- What it does not yet provide
- What implementation path will back it

## Interface discipline

- Use explicit states: Available, Unavailable, Loading, Running, Completed, Failed,
  RequiresPermission, RequiresConfiguration
- Do not silently substitute mock data for real integrations
- Do not store secrets in source code, config files, logs, or prompts

## Build and run

See `README.md` and `build_env.md`.

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --target tahoe-shell
./build/bin/tahoe-shell
```

## Before claiming a feature complete

- Implementation exists
- UI is connected to real behavior
- State persists where required
- Errors are handled
- Permissions are enforced
- Tests have been run
- Documentation is updated
- Feature status is reported accurately
