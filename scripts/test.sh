#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec nvim --headless -u NONE -l "$ROOT/scripts/test.lua"
