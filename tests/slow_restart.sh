#!/usr/bin/env bash
# Types <leader>;r into a real Neovim with gaps longer than 'timeoutlen', the way a person does.
# Keys fed from inside Neovim cannot do this: its timers stall while a mapping is pending.
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
gap="${1:-0.8}"
sock="$(mktemp -u "${TMPDIR:-/tmp}/lazygolf.XXXXXX").sock"

nvim --headless --listen "$sock" --cmd "set rtp^=$repo" </dev/null >/dev/null 2>&1 &
pid=$!
(sleep 30 && kill "$pid" 2>/dev/null) &
watchdog=$!
disown "$watchdog"
trap 'kill "$pid" "$watchdog" 2>/dev/null; rm -f "$sock"' EXIT

q() { nvim --server "$sock" --remote-expr "luaeval('$1')" 2>/dev/null; }
send() { nvim --server "$sock" --remote-send "$1" 2>/dev/null; }

for _ in $(seq 1 100); do [ -S "$sock" ] && break; sleep 0.1; done
sleep 1.5

q 'require("lazygolf.game").start(require("lazygolf.challenges").by_id["ops-ciw"]) or 1' >/dev/null
before="$(q 'tostring(require("lazygolf.game").state.session.buf)')"
send 'lll'
sleep 0.3
for key in '<Space>' ';' 'r'; do
  send "$key"
  sleep "$gap"
done
after="$(q 'tostring(require("lazygolf.game").state.session.buf)')"
keys="$(q 'require("lazygolf.game").state.keys')"

if [ -n "$after" ] && [ "$before" != "$after" ] && [ "$keys" = "0" ]; then
  echo "slow restart (${gap}s between keys)  PASS"
else
  echo "slow restart (${gap}s between keys)  FAIL before=$before after=${after:-<nvim stuck>} keys=${keys:-?}"
  exit 1
fi
