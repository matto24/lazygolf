---@class LazyGolf.TextGoal
---@field kind "text"
---@field lines string[]

---@class LazyGolf.CursorGoal
---@field kind "cursor"
---@field row integer 1-based
---@field col integer 0-based byte column

---@class LazyGolf.Challenge
---@field id string unique
---@field category string
---@field title string
---@field lesson string 1-3 sentences naming the keys
---@field filetype string
---@field start string[]
---@field cursor {[1]: integer, [2]: integer} 1-based row, 0-based col
---@field goal LazyGolf.TextGoal|LazyGolf.CursorGoal
---@field par integer
---@field solution string reference keys in termcode notation
---@field explain string shown after solving
---@field requires string? module that must be loadable for the drill to work

---@class LazyGolf.CategoryModule
---@field name string
---@field challenges LazyGolf.Challenge[]

local MODULES = {
  "motions",
  "text_objects",
  "operators",
  "repeat",
  "search_replace",
  "lazyvim",
  "refactor",
}

local M = {}

---@type LazyGolf.Challenge[]
M.list = {}
---@type table<string, LazyGolf.Challenge>
M.by_id = {}
---@type string[]
M.categories = {}

for _, name in ipairs(MODULES) do
  ---@type LazyGolf.CategoryModule
  local mod = require("lazygolf.challenges." .. name)
  M.categories[#M.categories + 1] = mod.name
  for _, ch in ipairs(mod.challenges) do
    assert(not M.by_id[ch.id], "duplicate challenge id: " .. ch.id)
    ch.category = mod.name
    M.by_id[ch.id] = ch
    M.list[#M.list + 1] = ch
  end
end

---@param ch LazyGolf.Challenge
---@return boolean
function M.available(ch)
  return ch.requires == nil or (pcall(require, ch.requires))
end

return M
