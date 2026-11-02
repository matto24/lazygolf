---@class LazyGolf.Progress
---@field best table<string, integer> best keystroke count per challenge id
local M = {}

---@type string?
M.path = nil

---@type LazyGolf.Progress?
local cache

---@return string
function M.file()
  return M.path or (vim.fn.stdpath("data") .. "/lazygolf.json")
end

---Drop the in-memory copy so the next access re-reads the file.
function M.reload()
  cache = nil
end

---@return LazyGolf.Progress
local function load()
  if cache then
    return cache
  end
  cache = { best = {} }
  local fd = io.open(M.file(), "r")
  if fd then
    local raw = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(vim.json.decode, raw)
    if ok and type(decoded) == "table" and type(decoded.best) == "table" then
      cache.best = decoded.best
    end
  end
  return cache
end

---@param id string
---@return integer?
function M.best(id)
  return load().best[id]
end

---@param par integer
---@param keys integer
---@return integer 3 when keys <= par, 2 when <= 1.5x par, otherwise 1
function M.stars_for(par, keys)
  if keys <= par then
    return 3
  elseif keys <= par * 1.5 then
    return 2
  end
  return 1
end

---@param challenge LazyGolf.Challenge
---@return integer 0 when never solved
function M.stars(challenge)
  local best = M.best(challenge.id)
  return best and M.stars_for(challenge.par, best) or 0
end

---Record a finished run. Persists only when it improves the best.
---@param id string
---@param keys integer
---@return boolean improved
function M.record(id, keys)
  local data = load()
  local prev = data.best[id]
  if prev and prev <= keys then
    return false
  end
  data.best[id] = keys
  vim.fn.mkdir(vim.fs.dirname(M.file()), "p")
  local fd = assert(io.open(M.file(), "w"))
  fd:write(vim.json.encode({ best = data.best }))
  fd:close()
  return true
end

return M
