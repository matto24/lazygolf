local challenges = require("lazygolf.challenges")

---@class LazyGolf.Session
---@field tab integer
---@field win integer
---@field buf integer
---@field info_win integer
---@field info_buf integer
---@field target_win integer?
---@field target_buf integer?

local M = {}

M.maps = { restart = "<leader>;r", menu = "<leader>;m", next = "<leader>;n" }

local ns = vim.api.nvim_create_namespace("lazygolf")
local group = vim.api.nvim_create_augroup("LazyGolf", { clear = true })

local function setup_highlights()
  local links = {
    LazyGolfTitle = "Title",
    LazyGolfDim = "Comment",
    LazyGolfGood = "DiagnosticOk",
    LazyGolfStar = "WarningMsg",
    LazyGolfKey = "Special",
    LazyGolfTarget = "IncSearch",
  }
  for name, link in pairs(links) do
    vim.api.nvim_set_hl(0, name, { default = true, link = link })
  end
end

local which_key_muted = false

---which-key swallows a prefix key and later re-feeds it, which the key counter would see twice.
---Muting it for nofile buffers while a game is open keeps the count exact.
---@param on boolean
local function mute_which_key(on)
  local config = package.loaded["which-key.config"]
  local bt = config and config.options and config.options.disable and config.options.disable.bt
  if not bt or on == which_key_muted then
    return
  end
  if on then
    table.insert(bt, "nofile")
  else
    for i = #bt, 1, -1 do
      if bt[i] == "nofile" then
        table.remove(bt, i)
        break
      end
    end
  end
  which_key_muted = on
end

---@type boolean?
local saved_timeout

---LazyVim's short 'timeoutlen' assumes which-key waits for the rest of a prefix. With it muted, a
---slowly typed `<leader>;r` would time out, so wait for the full sequence while the challenge is focused.
---@param on boolean
local function hold_pending_keys(on)
  if on and saved_timeout == nil then
    saved_timeout = vim.o.timeout
    vim.o.timeout = false
  elseif not on and saved_timeout ~= nil then
    vim.o.timeout = saved_timeout
    saved_timeout = nil
  end
end

---@param lines string[]
---@return integer
local function scratch(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

local INDENT = { lua = 2 }

---Pin indentation after the filetype plugins ran, so goals do not depend on the user's global shiftwidth.
---@param buf integer
local function apply_filetype(buf, ft)
  local width = INDENT[ft] or 4
  vim.bo[buf].filetype = ft
  vim.bo[buf].expandtab = true
  vim.bo[buf].shiftwidth = width
  vim.bo[buf].tabstop = width
  vim.bo[buf].softtabstop = width
end

---@param challenge LazyGolf.Challenge
---@return string
local function position_label(challenge)
  local idx, total = 0, 0
  for _, ch in ipairs(challenges.list) do
    if ch.category == challenge.category then
      total = total + 1
      if ch.id == challenge.id then
        idx = total
      end
    end
  end
  return ("%s %d/%d"):format(challenge.category, idx, total)
end

---@param challenge LazyGolf.Challenge
---@return LazyGolf.Session
function M.open(challenge)
  setup_highlights()
  mute_which_key(true)
  vim.cmd("tabnew")
  local win = vim.api.nvim_get_current_win()
  local blank = vim.api.nvim_win_get_buf(win)
  vim.bo[blank].bufhidden = "wipe"

  local buf = scratch(challenge.start)
  vim.api.nvim_win_set_buf(win, buf)
  apply_filetype(buf, challenge.filetype)
  vim.wo[win].winbar = "%!v:lua.require'lazygolf.layout'.winbar()"

  ---@type LazyGolf.Session
  local session = {
    tab = vim.api.nvim_get_current_tabpage(),
    win = win,
    buf = buf,
    info_win = -1,
    info_buf = -1,
  }

  if challenge.goal.kind == "text" then
    vim.cmd("rightbelow vsplit")
    session.target_win = vim.api.nvim_get_current_win()
    session.target_buf = scratch(challenge.goal.lines)
    vim.api.nvim_win_set_buf(session.target_win, session.target_buf)
    apply_filetype(session.target_buf, challenge.filetype)
    vim.bo[session.target_buf].modifiable = false
    vim.wo[session.target_win].winbar = "%#LazyGolfDim# target"
    for _, w in ipairs({ win, session.target_win }) do
      vim.api.nvim_win_call(w, function()
        vim.cmd("diffthis")
        vim.wo.foldenable = false
        vim.wo.wrap = false
      end)
    end
  else
    local goal = challenge.goal
    local line = challenge.start[goal.row] or ""
    local opts = { priority = 200, strict = false }
    if goal.col < #line then
      opts.end_col = goal.col + 1
      opts.hl_group = "LazyGolfTarget"
    else
      opts.virt_text = { { " ", "LazyGolfTarget" } }
      opts.virt_text_pos = "overlay"
    end
    vim.api.nvim_buf_set_extmark(buf, ns, goal.row - 1, math.min(goal.col, #line), opts)
  end

  vim.api.nvim_set_current_win(win)
  vim.cmd("topleft new")
  session.info_win = vim.api.nvim_get_current_win()
  session.info_buf = vim.api.nvim_win_get_buf(session.info_win)
  local ib = session.info_buf
  vim.bo[ib].buftype = "nofile"
  vim.bo[ib].bufhidden = "wipe"
  vim.bo[ib].swapfile = false
  vim.bo[ib].modifiable = false
  for opt, val in pairs({
    number = false,
    relativenumber = false,
    signcolumn = "no",
    cursorline = false,
    wrap = true,
    linebreak = true,
    winfixheight = true,
    foldenable = false,
    winbar = "",
  }) do
    vim.wo[session.info_win][opt] = val
  end

  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, challenge.cursor)

  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI" }, {
    group = group,
    buffer = buf,
    callback = function()
      require("lazygolf.game").evaluate()
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    pattern = "*:n",
    callback = function()
      vim.schedule(function()
        require("lazygolf.game").evaluate()
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave" }, {
    group = group,
    buffer = buf,
    callback = function(ev)
      hold_pending_keys(ev.event == "BufEnter")
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      require("lazygolf.game").on_closed(session)
    end,
  })

  local game = function(fn)
    return function()
      require("lazygolf.game")[fn]()
    end
  end
  vim.keymap.set("n", M.maps.restart, game("restart"), { buffer = buf, desc = "LazyGolf: restart" })
  vim.keymap.set("n", M.maps.menu, game("open_menu"), { buffer = buf, desc = "LazyGolf: menu" })
  vim.keymap.set("n", M.maps.next, game("next"), { buffer = buf, desc = "LazyGolf: next challenge" })
  hold_pending_keys(true)
  return session
end

function M.unmute()
  mute_which_key(false)
  hold_pending_keys(false)
end

---@param session LazyGolf.Session
---@param keep_muted boolean? true when another session is about to take over
function M.close(session, keep_muted)
  if vim.api.nvim_tabpage_is_valid(session.tab) then
    pcall(vim.cmd, ("tabclose! %d"):format(vim.api.nvim_tabpage_get_number(session.tab)))
  end
  for _, b in ipairs({ session.buf, session.info_buf, session.target_buf or -1 }) do
    if vim.api.nvim_buf_is_valid(b) then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  if not keep_muted then
    mute_which_key(false)
    hold_pending_keys(false)
  end
end

---@param session LazyGolf.Session
---@return boolean
function M.valid(session)
  return vim.api.nvim_buf_is_valid(session.buf) and vim.api.nvim_win_is_valid(session.win)
end

---@param n integer
local function stars_text(n)
  return string.rep("★", n) .. string.rep("☆", 3 - n)
end

---@return string
function M.winbar()
  local state = require("lazygolf.game").state
  if state.kind == "menu" then
    return ""
  end
  local par = state.challenge.par
  local text = ("%%#LazyGolfKey# keys %d%%* / par %d"):format(state.keys, par)
  if state.kind == "solved" then
    text = text .. ("  %%#LazyGolfGood#solved %s%%*"):format(stars_text(state.stars))
  end
  return text
end

---Redraw the live counter without touching buffers.
function M.refresh()
  pcall(vim.cmd, "redrawstatus!")
end

---@param state table the playing or solved game state
function M.render(state)
  local session, ch = state.session, state.challenge
  if not (vim.api.nvim_buf_is_valid(session.info_buf) and vim.api.nvim_win_is_valid(session.info_win)) then
    return
  end
  local lines = { position_label(ch) .. "  " .. ch.title, ch.lesson, "" }
  local goal_line = ch.goal.kind == "text" and "Goal: edit the left buffer until it matches the right one."
    or "Goal: move the cursor onto the highlighted cell."
  lines[#lines + 1] = goal_line
  if state.kind == "solved" then
    lines[#lines + 1] = ""
    local verdict = ("Solved in %d keys (par %d) %s"):format(state.keys, ch.par, stars_text(state.stars))
    if state.best then
      verdict = verdict .. ("  best %d"):format(state.best)
    end
    lines[#lines + 1] = verdict
    for _, l in ipairs(vim.split(ch.explain, "\n", { plain = true })) do
      lines[#lines + 1] = l
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("%s next unsolved   %s retry   %s menu"):format(M.maps.next, M.maps.restart, M.maps.menu)
  else
    lines[#lines + 1] = ("%s restart   %s menu   %s skip to next unsolved"):format(M.maps.restart, M.maps.menu, M.maps.next)
  end

  vim.bo[session.info_buf].modifiable = true
  vim.api.nvim_buf_set_lines(session.info_buf, 0, -1, false, lines)
  vim.bo[session.info_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(session.info_buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(session.info_buf, ns, 0, 0, { line_hl_group = "LazyGolfTitle" })
  vim.api.nvim_buf_set_extmark(session.info_buf, ns, 1, 0, { line_hl_group = "LazyGolfDim" })
  if state.kind == "solved" then
    vim.api.nvim_buf_set_extmark(session.info_buf, ns, 5, 0, { line_hl_group = "LazyGolfGood" })
  end

  local width = math.max(vim.api.nvim_win_get_width(session.info_win), 20)
  local rows = 0
  for _, l in ipairs(lines) do
    rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(l) / width))
  end
  vim.api.nvim_win_set_height(session.info_win, math.min(rows, math.floor(vim.o.lines / 2)))
  M.refresh()
end

M.stars_text = stars_text

return M
