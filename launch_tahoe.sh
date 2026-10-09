#!/bin/sh
# Project Tahoe X86 development launcher.
#
# Usage:
#   ./launch_tahoe.sh
#   ./launch_tahoe.sh --qt-qpa-platform xcb
#
# This is a development launcher for when the project has been built.
# It does not replace your current desktop session.
#
# Prerequisite: a successful build producing build/bin/tahoe-shell

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHELL_BIN="${SCRIPT_DIR}/build/bin/tahoe-shell"

if [ ! -x "${SHELL_BIN}" ]; then
  echo "Error: tahoe-shell not found at ${SHELL_BIN}" >&2
  echo "Build first with: cmake -S . -B build && cmake --build build --target tahoe-shell" >&2
  exit 1
fi

export TAHOE_HOME="${SCRIPT_DIR}"

exec "${SHELL_BIN}" "$@"
