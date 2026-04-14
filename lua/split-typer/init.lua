local M = {}

function M.open(category)
  require("split-typer.ui").open(category)
end

function M.setup(opts)
  -- Optional: user can override highlight groups, etc.
  -- For now this is a no-op placeholder for plugin manager compatibility
end

return M
