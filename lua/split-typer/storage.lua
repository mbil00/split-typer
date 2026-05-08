local M = {}

local data_dir = vim.fn.stdpath("data") .. "/split-typer"

local function write_file(path, content)
  local f = io.open(path, "w")
  if not f then
    return false
  end

  local ok = f:write(content)
  f:close()
  return ok ~= nil
end

function M.data_path(filename)
  return data_dir .. "/" .. filename
end

--- Resolve a per-layout data file path. QWERTY (the default) uses the
--- un-suffixed name so pre-refactor data files stay in use; other layouts
--- get a `<base>.<layout_id>.<ext>` suffix so their stats stay isolated.
function M.layout_data_path(base, ext)
  ext = ext or "json"
  local layouts = require("split-typer.layouts")
  local layout_id = (layouts.active and layouts.active.id) or "qwerty"
  if layout_id == "qwerty" then
    return data_dir .. "/" .. base .. "." .. ext
  end
  return data_dir .. "/" .. base .. "." .. layout_id .. "." .. ext
end

function M.read_json(path, default)
  local f = io.open(path, "r")
  if not f then
    return default
  end

  local content = f:read("*a")
  f:close()
  if not content or #content == 0 then
    return default
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    return decoded
  end

  local corrupt_path = string.format("%s.corrupt.%d", path, vim.uv.hrtime())
  local renamed = os.rename(path, corrupt_path)
  vim.schedule(function()
    local msg = "split-typer: failed to decode JSON at " .. path
    if renamed then
      msg = msg .. " (moved to " .. corrupt_path .. ")"
    else
      msg = msg .. " (could not preserve corrupt file)"
    end
    vim.notify(msg, vim.log.levels.WARN)
  end)

  return default
end

function M.write_json(path, value)
  vim.fn.mkdir(data_dir, "p")

  local ok, encoded = pcall(vim.json.encode, value)
  if not ok then
    return false
  end

  local temp_path = string.format("%s.tmp.%d.%d", path, vim.fn.getpid(), vim.uv.hrtime())
  if not write_file(temp_path, encoded) then
    return false
  end

  local renamed, rename_err = os.rename(temp_path, path)
  if not renamed then
    os.remove(temp_path)
    vim.schedule(function()
      vim.notify("split-typer: failed to save data: " .. tostring(rename_err), vim.log.levels.WARN)
    end)
    return false
  end

  return true
end

function M.append_capped(path, entry, cap)
  local items = M.read_json(path, {})
  items[#items + 1] = entry

  if cap and #items > cap then
    local trimmed = {}
    for i = #items - cap + 1, #items do
      trimmed[#trimmed + 1] = items[i]
    end
    items = trimmed
  end

  if not M.write_json(path, items) then
    return nil, false
  end

  return items, true
end

return M
