local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local only = vim.env.LAZYGOLF_ONLY

local results = {}
local failures = 0

local function out(s)
  io.stdout:write(s .. "\n")
  io.stdout:flush()
end

local function finish()
  out("")
  out(("%d passed, %d failed, %d skipped"):format(
    #vim.tbl_filter(function(r) return r.status == "PASS" end, results),
    failures,
    #vim.tbl_filter(function(r) return r.status == "SKIP" end, results)
  ))
  vim.cmd(failures == 0 and "qa!" or "cquit 1")
end

local co
local function resume()
  local ok, err = coroutine.resume(co)
  if not ok then
    out("HARNESS ERROR: " .. tostring(err))
    vim.cmd("cquit 2")
  elseif coroutine.status(co) == "dead" then
    finish()
  end
end

local function sleep(ms)
  vim.defer_fn(resume, ms)
  coroutine.yield()
end

local function wait_until(pred, timeout)
  local waited = 0
  while not pred() and waited < timeout do
    sleep(5)
    waited = waited + 5
  end
  return pred()
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "t", false)
end

local function record(r)
  results[#results + 1] = r
  if r.status == "FAIL" then
    failures = failures + 1
  end
end

local function setup_surround_for_tests()
  if pcall(require, "mini.surround") then
    return "installed"
  end
  local path = vim.env.LAZYGOLF_MINI_SURROUND
  if path and vim.uv.fs_stat(path) then
    vim.opt.rtp:append(path)
    require("mini.surround").setup({
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    })
    return "from LAZYGOLF_MINI_SURROUND"
  end
  return nil
end

local function run_challenges()
  if vim.env.LAZYGOLF_TRACE then
    vim.on_key(function(k, typed)
      out(("  key=%s typed=%s"):format(vim.fn.keytrans(k), vim.fn.keytrans(typed)))
    end, vim.api.nvim_create_namespace("lazygolf.trace"))
  end
  local game = require("lazygolf.game")
  local challenges = require("lazygolf.challenges")
  local lazygolf = require("lazygolf")

  for _, ch in ipairs(challenges.list) do
    if only and not ch.id:find(only, 1, true) then
      goto continue
    end
    local row = { id = ch.id, par = ch.par, keys = 0, status = "FAIL", note = "" }
    local function fail(msg)
      row.status, row.note = "FAIL", msg
      record(row)
    end

    if not challenges.available(ch) then
      row.status, row.note = "SKIP", "needs " .. ch.requires
      record(row)
      goto continue
    end

    local static = game.count_keys(vim.api.nvim_replace_termcodes(ch.solution, true, false, true))
    game.start(ch)
    local st = game.state
    if st.kind ~= "playing" then
      fail("state is " .. st.kind .. " after start")
      goto continue
    end
    local buf, win = st.session.buf, st.session.win
    if not vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), ch.start) then
      fail("buffer does not hold ch.start")
      goto continue
    end
    if not vim.deep_equal(vim.api.nvim_win_get_cursor(win), ch.cursor) then
      fail("cursor not at ch.cursor")
      goto continue
    end
    if lazygolf.check(ch, buf, win) then
      fail("start state already satisfies goal")
      goto continue
    end
    if vim.api.nvim_get_current_buf() ~= buf then
      fail("challenge buffer not focused")
      goto continue
    end

    feed(ch.solution)
    local solved = wait_until(function() return game.state.kind == "solved" end, 2500)
    sleep(30)
    row.keys = game.state.keys or 0
    if not solved then
      local got = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local pos = vim.api.nvim_win_get_cursor(win)
      fail(("not solved; mode=%s cursor=%d,%d keys=%d lines=%s"):format(
        vim.api.nvim_get_mode().mode, pos[1], pos[2], row.keys, vim.inspect(got):gsub("%s+", " ")))
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc><Esc>", true, false, true), "nx", false)
    elseif not lazygolf.check(ch, buf, win) then
      fail("solved state but check() is false")
    elseif row.keys ~= static then
      fail(("counted %d keys but solution has %d"):format(row.keys, static))
    elseif row.keys > ch.par then
      fail(("used %d keys, par %d"):format(row.keys, ch.par))
    elseif ch.par ~= static then
      fail(("par %d differs from solution length %d"):format(ch.par, static))
    else
      row.status = "PASS"
      record(row)
    end
    ::continue::
  end
end

local function test_progress()
  local progress = require("lazygolf.progress")
  local tmp = vim.fn.tempname() .. ".json"
  local saved = progress.path
  progress.path = tmp
  progress.reload()
  local ok = true
  local msgs = {}
  local function expect(cond, msg)
    if not cond then
      ok = false
      msgs[#msgs + 1] = msg
    end
  end
  expect(progress.best("a") == nil, "fresh file has no best")
  expect(progress.record("a", 10) == true, "first record improves")
  expect(progress.record("a", 12) == false, "worse run does not improve")
  expect(progress.record("a", 8) == true, "better run improves")
  progress.record("b", 3)
  progress.reload()
  expect(progress.best("a") == 8, "best persisted across reload")
  expect(progress.best("b") == 3, "second id persisted")
  expect(vim.fn.filereadable(tmp) == 1, "file written")
  expect(progress.stars_for(4, 4) == 3 and progress.stars_for(4, 6) == 2 and progress.stars_for(4, 7) == 1, "star thresholds")
  expect(progress.stars({ id = "a", par = 8 }) == 3 and progress.stars({ id = "zzz", par = 8 }) == 0, "stars from stored best")
  vim.fn.delete(tmp)
  progress.path = saved
  progress.reload()
  record({ id = "progress round trip", par = 0, keys = 0, status = ok and "PASS" or "FAIL", note = table.concat(msgs, "; ") })
end

local function test_state_machine()
  local progress = require("lazygolf.progress")
  local game = require("lazygolf.game")
  local challenges = require("lazygolf.challenges")
  local tmp = vim.fn.tempname() .. ".json"
  progress.path = tmp
  progress.reload()

  local ok, msgs = true, {}
  local function expect(cond, msg)
    if not cond then
      ok = false
      msgs[#msgs + 1] = msg
    end
  end

  local first = game.next_unsolved()
  expect(first == challenges.list[1], "next on fresh progress is the first challenge")
  vim.cmd("LazyGolf next")
  expect(game.state.kind == "playing" and game.state.challenge == first, ":LazyGolf next starts the first challenge")
  local tabs = #vim.api.nvim_list_tabpages()
  vim.cmd("LazyGolf reset")
  expect(game.state.kind == "playing" and game.state.keys == 0, ":LazyGolf reset restarts")
  expect(#vim.api.nvim_list_tabpages() == tabs, "reset replaces the game tab instead of stacking tabs")

  progress.record(first.id, first.par + 99)
  expect(game.next_unsolved() == challenges.list[2], "next skips solved challenges")

  vim.cmd("LazyGolf menu")
  expect(game.state.kind == "menu", "menu state after :LazyGolf")
  expect(#vim.api.nvim_list_tabpages() == tabs - 1, "menu closes the game tab")
  local menu_buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(menu_buf, 0, -1, false)
  expect(#lines > #challenges.list, "menu lists every challenge")
  vim.api.nvim_input("<CR>")
  wait_until(function() return game.state.kind == "playing" end, 500)
  expect(game.state.kind == "playing" and game.state.challenge == challenges.list[2], "<CR> in the menu starts the cursor row's challenge")

  game.open_menu()
  vim.api.nvim_input("q")
  sleep(30)
  vim.fn.delete(tmp)
  progress.path = nil
  progress.reload()
  record({ id = "state machine + commands", par = 0, keys = 0, status = ok and "PASS" or "FAIL", note = table.concat(msgs, "; ") })
end

local function test_game_flow()
  local progress = require("lazygolf.progress")
  local game = require("lazygolf.game")
  local challenges = require("lazygolf.challenges")
  local tmp = vim.fn.tempname() .. ".json"
  progress.path = tmp
  progress.reload()

  local ok, msgs = true, {}
  local function expect(cond, msg)
    if not cond then
      ok = false
      msgs[#msgs + 1] = msg
    end
  end

  local text_ch = challenges.by_id["ops-ciw"]
  local cursor_ch = challenges.by_id["motions-count-w"]

  game.start(text_ch)
  local s = game.state.session
  expect(vim.wo[s.win].diff and vim.wo[s.target_win].diff, "text goal shows both windows in diff mode")
  expect(not vim.bo[s.target_buf].modifiable, "target buffer is read-only")
  expect(vim.bo[s.buf].filetype == text_ch.filetype, "filetype applied to the challenge buffer")
  local winbar = vim.api.nvim_eval_statusline(vim.wo[s.win].winbar, { winid = s.win }).str
  expect(winbar:find("keys 0 / par " .. text_ch.par, 1, true) ~= nil, "winbar shows keys and par: " .. winbar)

  feed(text_ch.solution)
  wait_until(function() return game.state.kind == "solved" end, 2000)
  sleep(30)
  expect(game.state.kind == "solved", "solved after the reference solution")
  local info = table.concat(vim.api.nvim_buf_get_lines(s.info_buf, 0, -1, false), "\n")
  expect(info:find("Solved in " .. text_ch.par .. " keys", 1, true) ~= nil, "info panel reports the result")
  expect(info:find(text_ch.explain:sub(1, 20), 1, true) ~= nil, "info panel shows the explanation")
  expect(progress.best(text_ch.id) == text_ch.par, "best recorded in progress")
  expect(vim.fn.filereadable(tmp) == 1, "progress file written on solve")
  local solved_keys = game.state.keys
  feed("lll")
  sleep(50)
  expect(game.state.kind == "solved" and game.state.keys == solved_keys, "keys after solving are not counted")

  feed("<leader>;r")
  wait_until(function() return game.state.kind == "playing" end, 1000)
  sleep(30)
  expect(game.state.kind == "playing" and game.state.keys == 0, "restart key returns to a fresh playing state")
  expect(vim.deep_equal(vim.api.nvim_buf_get_lines(game.state.session.buf, 0, -1, false), text_ch.start), "restart restores the start text")

  game.start(cursor_ch)
  s = game.state.session
  local marks = vim.api.nvim_buf_get_extmarks(s.buf, vim.api.nvim_create_namespace("lazygolf"), 0, -1, {})
  expect(#marks == 1 and s.target_win == nil, "cursor goal highlights one cell and has no target window")

  local before = #vim.api.nvim_list_tabpages()
  vim.cmd("tabclose")
  sleep(30)
  expect(game.state.kind == "menu", "closing the game tab returns to the menu state")
  expect(#vim.api.nvim_list_tabpages() == before - 1, "tab closed")

  vim.fn.delete(tmp)
  progress.path = nil
  progress.reload()
  record({ id = "game flow (ui, restart, close)", par = 0, keys = 0, status = ok and "PASS" or "FAIL", note = table.concat(msgs, "; ") })
end

local function main()
  vim.opt.rtp:prepend(root)
  vim.cmd("runtime plugin/lazygolf.lua")
  package.loaded["lazygolf"] = nil

  wait_until(function() return vim.g.lazygolf_test_verylazy end, 3000)
  if not vim.g.lazygolf_test_verylazy then
    vim.cmd("doautocmd User VeryLazy")
  end
  sleep(300)

  local surround = setup_surround_for_tests()
  out("mini.surround: " .. (surround or "not available, surround drills will be skipped"))

  local progress = require("lazygolf.progress")
  progress.path = vim.fn.tempname() .. ".json"
  progress.reload()

  run_challenges()
  progress.path = nil
  progress.reload()
  if not only then
    test_progress()
    test_state_machine()
    test_game_flow()
  end

  out(("%-34s %5s %5s  %s"):format("challenge", "keys", "par", "result"))
  for _, r in ipairs(results) do
    out(("%-34s %5s %5s  %s %s"):format(r.id, r.keys, r.par, r.status, r.note))
  end
end

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    vim.g.lazygolf_test_verylazy = true
  end,
})
vim.defer_fn(function()
  out("TIMEOUT")
  vim.cmd("cquit 3")
end, 180000)

co = coroutine.create(main)
vim.schedule(resume)
