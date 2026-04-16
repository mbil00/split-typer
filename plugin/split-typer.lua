if vim.g.loaded_split_typer then
  return
end
vim.g.loaded_split_typer = true

vim.api.nvim_create_user_command("SplitTyper", function(opts)
  require("split-typer").open(opts.args)
end, {
  nargs = "?",
  desc = "Open Split Typer - adaptive touch-typing practice for keyboards",
  complete = function()
    local exercises = require("split-typer.exercises")
    local ids = { "course", "dashboard", "timed", "combos", "reaction", "transitions", "weak_keys" }
    for _, group in ipairs(exercises.get_groups()) do
      ids[#ids + 1] = group.id
    end
    for _, cat in ipairs(exercises.get_categories()) do
      ids[#ids + 1] = cat.id
    end
    for _, cat in ipairs(exercises.get_reaction_categories()) do
      ids[#ids + 1] = cat.id
    end
    return ids
  end,
})
