local challenges = require("lazygolf.challenges")
local progress = require("lazygolf.progress")
local layout = require("lazygolf.layout")

local M = {}

local ns = vim.api.nvim_create_namespace("lazygolf.menu")

---@return string[] lines
---@return table<integer, LazyGolf.Challenge> rows
---@return table<integer, boolean> headers
local function build()
  local solved = 0
  for _, ch in ipairs(challenges.list) do
    solved = solved + (progress.stars(ch) > 0 and 1 or 0)
  end
  local lines = { ("%d / %d solved   <CR> play   q close"):format(solved, #challenges.list) }
  local rows, headers = {}, {}
  for _, category in ipairs(challenges.categories) do
    lines[#lines + 1] = ""
    lines[#lines + 1] = category
    headers[#lines] = true
    for _, ch in ipairs(challenges.list) do
      if ch.category == category then
        local best = progress.best(ch.id)
        local suffix = best and ("best %d"):format(best) or ""
        if not challenges.available(ch) then
          suffix = ("needs %s"):format(ch.requires)
        end
        local row = ("  %s  %-46s par %-3d %s"):format(layout.stars_text(progress.stars(ch)), ch.title, ch.par, suffix)
        lines[#lines + 1] = vim.trim(row) == "" and row or row:gsub("%s+$", "")
        rows[#lines] = ch
      end
    end
  end
  return lines, rows, headers
end

---@type integer?
local open_win

function M.open()
  if open_win and vim.api.nvim_win_is_valid(open_win) then
    vim.api.nvim_win_close(open_win, true)
  end
  local lines, rows, headers = build()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local width = math.min(84, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " LazyGolf ",
    title_pos = "center",
  })
  open_win = win
  for opt, val in pairs({
    cursorline = true,
    wrap = false,
    list = false,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    statuscolumn = "",
    foldenable = false,
  }) do
    vim.wo[win][opt] = val
  end

  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { line_hl_group = "LazyGolfDim" })
  for lnum in pairs(headers) do
    vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, { line_hl_group = "LazyGolfTitle" })
  end
  for lnum, ch in pairs(rows) do
    local stars = progress.stars(ch)
    vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 2, { end_col = 2 + #layout.stars_text(stars), hl_group = "LazyGolfStar" })
  end

  local first = 3
  for lnum = 1, #lines do
    if rows[lnum] and challenges.available(rows[lnum]) and progress.stars(rows[lnum]) == 0 then
      first = lnum
      break
    end
  end
  vim.api.nvim_win_set_cursor(win, { first, 0 })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", function()
    local ch = rows[vim.api.nvim_win_get_cursor(win)[1]]
    if not ch then
      return
    end
    close()
    require("lazygolf.game").start(ch)
  end, { buffer = buf, nowait = true })
end

return M
