local M = {}

function M.open(category)
  require("split-typer.ui").open(category)
end

function M.setup(opts)
  opts = opts or {}
  if opts.layout then
    local layouts = require("split-typer.layouts")
    layouts.rebuild(opts.layout)
  end
end

return M
