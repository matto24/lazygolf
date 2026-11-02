if vim.g.loaded_lazygolf then
  return
end
vim.g.loaded_lazygolf = true

vim.api.nvim_create_user_command("LazyGolf", function(opts)
  require("lazygolf").command(opts.args)
end, {
  nargs = "?",
  desc = "LazyGolf: edit-practice trainer",
  complete = function()
    return require("lazygolf").subcommands
  end,
})
