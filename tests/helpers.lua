local M = {}

local function clear_modules(prefix)
  for name in pairs(package.loaded) do
    if name == prefix or name:match("^" .. prefix:gsub("%-", "%%-") .. "%.") then
      package.loaded[name] = nil
    end
  end
end

function M.clear_split_typer_modules()
  clear_modules("split-typer")
  vim.g.loaded_split_typer = nil
end

function M.tmpdir(label)
  local path = vim.fn.tempname() .. "-" .. (label or "split-typer")
  vim.fn.mkdir(path, "p")
  return path
end

function M.with_isolated_env(label, fn)
  local root = M.tmpdir(label)
  local old_data = vim.env.XDG_DATA_HOME
  local old_state = vim.env.XDG_STATE_HOME
  local old_cache = vim.env.XDG_CACHE_HOME
  vim.env.XDG_DATA_HOME = root .. "/data"
  vim.env.XDG_STATE_HOME = root .. "/state"
  vim.env.XDG_CACHE_HOME = root .. "/cache"
  vim.fn.mkdir(vim.env.XDG_DATA_HOME, "p")
  vim.fn.mkdir(vim.env.XDG_STATE_HOME, "p")
  vim.fn.mkdir(vim.env.XDG_CACHE_HOME, "p")
  M.clear_split_typer_modules()

  local ok, result = pcall(fn, root)

  M.clear_split_typer_modules()
  vim.env.XDG_DATA_HOME = old_data
  vim.env.XDG_STATE_HOME = old_state
  vim.env.XDG_CACHE_HOME = old_cache

  if not ok then
    error(result, 0)
  end
  return result
end

function M.assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assert_eq failed") .. string.format("\nexpected: %s\nactual: %s", vim.inspect(expected), vim.inspect(actual)), 0)
  end
end

function M.assert_truthy(value, msg)
  if not value then
    error(msg or ("expected truthy value, got " .. vim.inspect(value)), 0)
  end
end

function M.assert_match(text, pattern, msg)
  if type(text) ~= "string" or not text:match(pattern) then
    error((msg or "assert_match failed") .. string.format("\npattern: %s\ntext: %s", pattern, vim.inspect(text)), 0)
  end
end

function M.assert_contains(text, needle, msg)
  if type(text) ~= "string" or not text:find(needle, 1, true) then
    error((msg or "assert_contains failed") .. string.format("\nneedle: %s\ntext: %s", needle, vim.inspect(text)), 0)
  end
end

function M.read_file(path)
  local f = assert(io.open(path, "r"))
  local content = f:read("*a")
  f:close()
  return content
end

function M.make_visible_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  return buf, vim.api.nvim_get_current_win()
end

function M.cleanup_ui()
  local ok, ui = pcall(require, "split-typer.ui")
  if ok and ui and ui.cleanup then
    pcall(ui.cleanup)
  end
end

return M
