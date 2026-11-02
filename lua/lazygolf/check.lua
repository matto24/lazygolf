local M = {}

---@param challenge LazyGolf.Challenge
---@param bufnr integer
---@param winid integer
---@return boolean
function M.check(challenge, bufnr, winid)
  local goal = challenge.goal
  if goal.kind == "text" then
    return vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), goal.lines)
  end
  local pos = vim.api.nvim_win_get_cursor(winid)
  return pos[1] == goal.row and pos[2] == goal.col
end

return M
