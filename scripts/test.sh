#!/usr/bin/env bash
# Runs every challenge's reference solution through the real game in headless Neovim with your own config.
# LAZYGOLF_ONLY=<substring> limits to matching ids. LAZYGOLF_MINI_SURROUND=<dir> points at a mini.surround
# checkout so the surround drills can run when the plugin is not installed in your LazyVim.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
exec nvim --headless -c "luafile ${here}/tests/run.lua"
