local M = {}

local data_dir = vim.fn.stdpath("data") .. "/split-typer"

function M.data_path(filename)
  return data_dir .. "/" .. filename
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

  return default
end

function M.write_json(path, value)
  vim.fn.mkdir(data_dir, "p")
  local f = io.open(path, "w")
  if not f then
    return false
  end

  f:write(vim.json.encode(value))
  f:close()
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

  M.write_json(path, items)
  return items
end

return M
