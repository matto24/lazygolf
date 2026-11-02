local challenges = require("lazygolf.challenges")
local progress = require("lazygolf.progress")
local layout = require("lazygolf.layout")

---@class LazyGolf.MenuState
---@field kind "menu"

---@class LazyGolf.PlayingState
---@field kind "playing"
---@field challenge LazyGolf.Challenge
---@field session LazyGolf.Session
---@field keys integer

---@class LazyGolf.SolvedState
---@field kind "solved"
---@field challenge LazyGolf.Challenge
---@field session LazyGolf.Session
---@field keys integer
---@field stars integer
---@field best integer? best across all runs, nil when never recorded

---@alias LazyGolf.State LazyGolf.MenuState|LazyGolf.PlayingState|LazyGolf.SolvedState

local M = {}

---@type LazyGolf.State
M.state = { kind = "menu" }

local ALLOWED = {
  menu = { menu = true, playing = true },
  playing = { menu = true, playing = true, solved = true },
  solved = { menu = true, playing = true },
}

---@param next_state LazyGolf.State
local function transition(next_state)
  assert(ALLOWED[M.state.kind][next_state.kind], ("illegal transition %s -> %s"):format(M.state.kind, next_state.kind))
  M.state = next_state
end

---Typed input can arrive batched ("iw" from a text-object mapping), so count keys, not calls.
---@param typed string
---@return integer
function M.count_keys(typed)
  local rest, tokens = vim.fn.keytrans(typed):gsub("<[%w%-_]+>", "")
  return tokens + vim.fn.strchars(rest)
end

vim.on_key(function(_, typed)
  local s = M.state
  if s.kind ~= "playing" or typed == "" then
    return
  end
  if vim.api.nvim_get_current_buf() ~= s.session.buf then
    return
  end
  s.keys = s.keys + M.count_keys(typed)
  vim.schedule(layout.refresh)
end, vim.api.nvim_create_namespace("lazygolf.keys"))

---@return LazyGolf.Session?
local function current_session()
  return M.state.kind ~= "menu" and M.state.session or nil
end

---@param challenge LazyGolf.Challenge
function M.start(challenge)
  if not challenges.available(challenge) then
    vim.notify(("LazyGolf: '%s' needs %s, which is not installed."):format(challenge.title, challenge.requires), vim.log.levels.WARN)
    return
  end
  local previous = current_session()
  local session = layout.open(challenge)
  transition({ kind = "playing", challenge = challenge, session = session, keys = 0 })
  if previous then
    layout.close(previous)
  end
  layout.render(M.state)
end

function M.restart()
  local s = M.state
  if s.kind == "menu" then
    vim.notify("LazyGolf: no challenge to restart.", vim.log.levels.INFO)
    return
  end
  M.start(s.challenge)
end

function M.open_menu()
  local previous = current_session()
  transition({ kind = "menu" })
  if previous then
    layout.close(previous)
  end
  require("lazygolf.menu").open()
end

---First never-solved challenge, then the first without three stars.
---@return LazyGolf.Challenge?
function M.next_unsolved()
  local fallback
  for _, ch in ipairs(challenges.list) do
    if challenges.available(ch) then
      local stars = progress.stars(ch)
      if stars == 0 then
        return ch
      end
      fallback = fallback or (stars < 3 and ch or nil)
    end
  end
  return fallback
end

function M.next()
  local ch = M.next_unsolved()
  if not ch then
    vim.notify("LazyGolf: every challenge is at three stars.", vim.log.levels.INFO)
    return
  end
  M.start(ch)
end

---@param session LazyGolf.Session
function M.on_closed(session)
  if current_session() == session then
    transition({ kind = "menu" })
  end
end

local function solve()
  local s = M.state
  ---@cast s LazyGolf.PlayingState
  progress.record(s.challenge.id, s.keys)
  transition({
    kind = "solved",
    challenge = s.challenge,
    session = s.session,
    keys = s.keys,
    stars = progress.stars_for(s.challenge.par, s.keys),
    best = progress.best(s.challenge.id),
  })
  layout.render(M.state)
end

---Called from the challenge buffer's autocmds; only a settled normal-mode state can win.
function M.evaluate()
  local s = M.state
  if s.kind ~= "playing" or not layout.valid(s.session) then
    return
  end
  if vim.api.nvim_get_current_buf() ~= s.session.buf or vim.api.nvim_get_mode().mode ~= "n" then
    return
  end
  if require("lazygolf.check").check(s.challenge, s.session.buf, s.session.win) then
    solve()
  end
end

return M
