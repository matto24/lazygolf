local M = {}

---Whether the buffer/window currently satisfies the challenge goal. Pure, no game state.
---@param challenge LazyGolf.Challenge
---@param bufnr integer
---@param winid integer
---@return boolean
function M.check(challenge, bufnr, winid)
  return require("lazygolf.check").check(challenge, bufnr, winid)
end

M.subcommands = { "menu", "next", "reset", "reset-progress" }

---@param arg string?
function M.command(arg)
  local game = require("lazygolf.game")
  arg = vim.trim(arg or "")
  if arg == "" or arg == "menu" then
    game.open_menu()
  elseif arg == "next" then
    game.next()
  elseif arg == "reset" or arg == "restart" then
    game.restart()
  elseif arg == "reset-progress" then
    game.reset_progress()
  else
    vim.notify("LazyGolf: unknown subcommand '" .. arg .. "' (menu, next, reset, reset-progress)", vim.log.levels.ERROR)
  end
end

return M
