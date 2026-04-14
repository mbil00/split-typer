if vim.g.loaded_split_typer then
  return
end
vim.g.loaded_split_typer = true

vim.api.nvim_create_user_command("SplitTyper", function(opts)
  require("split-typer").open(opts.args)
end, {
  nargs = "?",
  desc = "Open Split Typer - typing practice for split keyboards",
  complete = function()
    local cats = require("split-typer.exercises").get_categories()
    local ids = { "course", "dashboard" }
    for _, cat in ipairs(cats) do
      ids[#ids + 1] = cat.id
    end
    return ids
  end,
})
