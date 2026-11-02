# LazyGolf

Short, scored reps for the edits you do all day in LazyVim. Each challenge gives you some code, a goal, and a keystroke budget (par). You edit in your real Neovim with your real keymaps, so what you learn is the muscle memory you will actually use.

## Install

With lazy.nvim (LazyVim), add a spec:

```lua
{ dir = "~/Documents/lazyvim_game", name = "lazygolf", cmd = "LazyGolf" }
```

Needs Neovim 0.10+. The surround drills (`gsa`, `gsd`, `gsr`) need the LazyVim `coding.mini-surround` extra (`:LazyExtras`). Without it those drills are listed as unavailable and skipped by `:LazyGolf next`.

## Play

| Command | What it does |
| --- | --- |
| `:LazyGolf` | Menu of categories and challenges with your stars. `<CR>` plays, `q` closes. |
| `:LazyGolf next` | Jump to the first unsolved challenge, then the first without three stars. |
| `:LazyGolf reset` | Restart the current challenge. |

Inside a challenge (opens in a new tab):

- Left is the challenge buffer, right is the target with diff highlighting. Motion drills have no target; move the cursor onto the highlighted cell.
- The top panel shows the lesson. The winbar shows `keys N / par P` live.
- `<leader>;r` restart, `<leader>;n` next unsolved, `<leader>;m` menu (buffer-local, free in stock LazyVim).
- A text goal is checked once you are back in Normal mode, so the `<Esc>` counts. Stars: 3 at or under par, 2 at or under 1.5x par, 1 for solving.
- Best scores are stored in `stdpath("data") .. "/lazygolf.json"`.

Par is the reference solution's key count, not a proven optimum. Beating it is fine and encouraged.

Notes on how it is measured:

- Keys are counted with `vim.on_key` while the challenge buffer is focused. Counts, text-object letters and `<leader>` presses each count as keys.
- which-key is muted for `nofile` buffers while a challenge is open. It swallows prefixes like `g` and feeds them back, which would double count. It is restored when you leave.
- Indentation is pinned per filetype (2 for Lua, 4 for the rest) so goals do not depend on your global `shiftwidth`.
- Your own auto-pairs, completion and mappings stay active. Some solutions rely on `mini.pairs` closing a bracket for you.

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
./scripts/test.sh                              # every challenge, with your own Neovim config
LAZYGOLF_ONLY=ops- ./scripts/test.sh           # ids containing a substring
LAZYGOLF_MINI_SURROUND=/path/to/mini.surround ./scripts/test.sh   # run surround drills without the extra
```

The runner starts `nvim --headless` with your config, waits for `VeryLazy`, plays each challenge through `game.start`, types the reference `solution` into the typeahead so the real main loop, mappings and autocmds handle it, and checks goal, key count and par. It also covers progress persistence and the menu/restart/close flow. Exit code is non-zero on any failure.
