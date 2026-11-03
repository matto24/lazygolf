# LazyGolf

Short, scored reps for the edits you make all day in LazyVim. Each challenge gives you a snippet of code, a goal, and a keystroke budget (par). You play inside your own Neovim, with your own config and keymaps, so the muscle memory you build is the one you actually use.

There are 74 challenges in seven categories, from `w` and `f` up to macros, `:s` with `\=`, and LazyVim's mini.ai, flash and surround keymaps.

## Requirements

- Neovim 0.10 or newer.
- [LazyVim](https://www.lazyvim.org/) for the LazyVim category. Every other category works in plain Neovim.
- Optional: the LazyVim `coding.mini-surround` extra (enable it from `:LazyExtras`) for the four surround drills (`gsa`, `gsd`, `gsr`). Without it they show as unavailable and `:LazyGolf next` skips them.

## Install

With lazy.nvim, which LazyVim uses, add a spec file such as `~/.config/nvim/lua/plugins/lazygolf.lua`:

```lua
return {
  { "matto24/lazygolf", cmd = "LazyGolf" },
}
```

The plugin only loads when you run `:LazyGolf`, so it costs nothing at startup.

To hack on a local checkout instead, point lazy.nvim at the folder:

```lua
return {
  { dir = "~/path/to/lazygolf", name = "lazygolf", cmd = "LazyGolf" },
}
```

## Quick start

1. Run `:LazyGolf next`. It opens the first challenge you have not solved yet.
2. Read the lesson in the top panel. It names the keys the challenge is about.
3. Make the left buffer match the target on the right, or move the cursor onto the highlighted cell.
4. When you get back to Normal mode in the goal state, the panel shows your score and an explanation of the reference solution.
5. Press `<leader>;n` for the next one, or `<leader>;r` to try again for a better score.

## Commands

| Command | What it does |
| --- | --- |
| `:LazyGolf` | Opens the menu of categories and challenges with your stars. `<CR>` plays the challenge under the cursor, `q` or `<Esc>` closes. |
| `:LazyGolf next` | Jumps to the first unsolved challenge, then to the first one without three stars. |
| `:LazyGolf reset` | Restarts the current challenge. |

## Inside a challenge

Each challenge opens in its own tab.

- **The challenge buffer** is on the left. This is where you type, and only keys typed here count.
- **The target** is on the right, with diff highlighting showing what is still different. Motion drills have no target. You move the cursor onto the highlighted cell instead.
- **The lesson panel** is on top. After you solve, it shows your result, your best score, and why the reference solution works.
- **The winbar** shows `keys N / par P` live as you type.

These keys work only in the challenge buffer:

| Key | Action |
| --- | --- |
| `<leader>;r` | Restart the current challenge |
| `<leader>;n` | Go to the next unsolved challenge |
| `<leader>;m` | Open the menu |

The `<leader>;` prefix is unused in stock LazyVim, so nothing of yours is shadowed. You can type these sequences as slowly as you like (see [How keys are counted](#how-keys-are-counted)).

Closing the tab (`:tabclose`) ends the game. Your progress is already saved.

## Scoring

- **Three stars.** Solved at or under par.
- **Two stars.** Solved at or under 1.5 times par.
- **One star.** Solved at all.

A text goal is checked once you are back in Normal mode, so the final `<Esc>` counts as a key. Keys typed after you solve are not counted.

Par is the key count of a reference solution, not a proven optimum. Beating par is fine and encouraged.

Best scores are stored in `stdpath("data") .. "/lazygolf.json"`, usually `~/.local/share/nvim/lazygolf.json`. Delete that file to reset all progress.

## Categories

| Category | Drills | What you practise |
| --- | --- | --- |
| Motions | 10 | `w`, `$`, `^`, `f` with `;`, `%`, `W`, `e`, `}`, `G`, `#` |
| Text objects | 9 | `ci"`, `ci(`, `ci[`, `ciW`, `daw`, `dap`, `di{`, `ci<`, `>i{` |
| Operators | 12 | `ciw`, `cw`, `r`, `R`, `~`, `gUiw`, `xp`, `ddp`, `D`, `cc`, `J`, `viwp` |
| Repeat | 7 | `.`, counts, `;` with `.`, `cgn`, macros, `@@` |
| Search & replace | 10 | `:s`, `:%s`, `\<word\>`, ranges, visual ranges, `&`, `:g`, `\=` |
| LazyVim | 15 | mini.surround (`gsa`, `gsd`, `gsr`), mini.ai (`daa`, `cia`, `ciq`, `cif`), flash (`s`), comments (`gcc`, `gc`, `gco`), moving lines (`<A-j>`, `<A-k>`), `]f` |
| Refactor | 11 | Multi-step, real-world edits: rename, swap arguments, extract a variable, wrap a call, change a signature |

Challenges are played in the order above. Each category's order goes from easy to hard.

## How keys are counted

LazyGolf counts keys with `vim.on_key` while the challenge buffer has focus. Counts, text-object letters and each key of `<leader>` count, so `3w` is two keys and `<leader>;r` is three.

To keep counts exact and the game playable, LazyGolf changes two things while a challenge is open. Both are put back when you leave.

- **which-key is muted for `nofile` buffers.** which-key swallows prefixes like `g` and feeds them back, so they would count twice. You get no which-key popup inside a challenge.
- **`'timeout'` is turned off while the challenge buffer has focus.** LazyVim's short `timeoutlen` (300 ms) relies on which-key waiting for the rest of a prefix. With which-key muted, a slowly typed `<leader>;r` would otherwise time out and run as plain keys. With `'timeout'` off, Neovim waits for you to finish a mapping, just as which-key does. `'timeout'` is restored as soon as you switch to another buffer or close the game.

Indentation is pinned per filetype (2 for Lua, 4 for everything else), so goals do not depend on your global `shiftwidth`.

Everything else is yours. Your mappings, auto-pairs and completion stay active while you play.

## Your config and par

Par is measured against stock LazyVim. Tests confirm that every category except LazyVim also reaches par in plain `nvim --clean`, auto-pairs or not. The LazyVim category needs the LazyVim keymaps and plugins it names.

If you have remapped keys a solution uses (for example `s`, `gc` or `<A-j>`), your best score on that drill may not match par. You can still solve it your way.

## Troubleshooting

- **A surround drill says it is unavailable.** Enable the `coding.mini-surround` extra in `:LazyExtras` and restart Neovim.
- **My key count looks one too high.** The final `<Esc>` back to Normal mode counts. So does each key of a count or `<leader>` sequence.
- **A LazyVim drill cannot be solved.** Check that the keymap it teaches does what the lesson says in a normal buffer. A custom mapping on that key changes the behaviour.

## Add a challenge

Add a table to the matching file in `lua/lazygolf/challenges/` (`motions`, `text_objects`, `operators`, `repeat`, `search_replace`, `lazyvim`, `refactor`). Order in the file is play order.

```lua
{
  id = "ops-ciw",                 -- unique
  title = "Change a word",
  lesson = "`ciw` deletes the word under the cursor and starts insert mode.",
  filetype = "python",
  start = { "total = price * qty" },
  cursor = { 1, 8 },              -- 1-based row, 0-based col
  goal = { kind = "text", lines = { "total = cost * qty" } },
  -- or: goal = { kind = "cursor", row = 1, col = 14 },
  par = 8,
  solution = "ciwcost<Esc>",      -- termcode notation, as for nvim_replace_termcodes
  explain = "Why this is the shortest way.",
  -- requires = "mini.surround",  -- optional: skipped when the module is missing
},
```

Then run the tests. `par` must equal the key count of `solution`, the solution must reach the goal through the real game, and the start state must not already satisfy the goal.

## Tests

```sh
./scripts/test.sh                              # every challenge plus the game-flow tests, with your own config
LAZYGOLF_ONLY=ops- ./scripts/test.sh           # only challenge ids containing a substring
LAZYGOLF_MINI_SURROUND=/path/to/mini.surround ./scripts/test.sh   # run the surround drills without the extra
```

`tests/run.lua` starts `nvim --headless` with your config and waits for `VeryLazy`. It then plays each challenge through the real game. It types the reference `solution` into the typeahead, so your mappings and autocmds handle it, and it checks the goal, the key count and par. It also covers progress persistence and the menu, restart and close flow.

`tests/slow_restart.sh` starts a separate Neovim and sends `<leader>;r` over its RPC socket with 0.8 s between keys, the way a person types. Keys fed from inside Neovim cannot test this, because its timers stall while a mapping is pending.

The exit code is non-zero on any failure.

## License

MIT. See [LICENSE](LICENSE).
