local M = {}

function M.open(category)
  require("split-typer.ui").open(category)
end

--- Read a newline/whitespace-separated word file from disk.
--- @param path string
--- @return string[]|nil, string|nil
local function read_word_file(path)
  local expanded = vim.fn.expand(path)
  local f, err = io.open(expanded, "r")
  if not f then
    return nil, err or ("cannot open " .. expanded)
  end
  local content = f:read("*a")
  f:close()
  return { content }, nil
end

local function resolve_extra_words(source)
  if source == nil then
    return nil
  end
  if type(source) == "string" then
    local list, err = read_word_file(source)
    if not list then
      vim.notify("split-typer: extra_words file error: " .. err, vim.log.levels.WARN)
      return nil
    end
    return list
  end
  if type(source) == "table" then
    return source
  end
  vim.notify(
    "split-typer: extra_words must be a file path (string) or an array of words (table), got " .. type(source),
    vim.log.levels.WARN
  )
  return nil
end

function M.setup(opts)
  opts = opts or {}
  if opts.layout then
    local layouts = require("split-typer.layouts")
    layouts.rebuild(opts.layout)
  end
  if opts.extra_words ~= nil then
    local list = resolve_extra_words(opts.extra_words)
    if list then
      require("split-typer.words").set_extra_words(list)
    end
  end
end

return M
