local positions = require("split-typer.layouts.positions")

local M = {
  char_meta = {},
  chars_by_row = { number = "", top = "", home = "", bottom = "" },
  chars_by_col = {},
  chars_by_hand = { left = "", right = "" },
  letter_chars = "",
  center_left = {},
  center_right = {},
  cross_center_pairs = {},
  shifted_number_symbols = {},
  active = nil,
}

local available = {}

local VALID_HANDS = { left = true, right = true, thumbs = true }
local VALID_FINGERS = {
  pinky = true, ring = true, middle = true, index = true,
  number = true, thumb = true,
}
local VALID_ROWS = {
  outer = true, inner = true, center = true, number = true, thumb = true,
}
local REQUIRED_ROW_NAMES = { "number", "top", "home", "bottom" }

local function validate_row_array(arr, path)
  if type(arr) ~= "table" then
    return false, path .. " must be an array of 10 single-character strings"
  end
  if #arr ~= 10 then
    return false, path .. " has " .. #arr .. " entries, expected 10"
  end
  for i = 1, 10 do
    local v = arr[i]
    if type(v) ~= "string" then
      return false, path .. "[" .. i .. "] must be a single-character string, got " .. type(v)
    end
    if #v ~= 1 then
      return false, path .. "[" .. i .. "] = " .. vim.inspect(v) .. ", expected a single-character string"
    end
  end
  return true
end

local function validate_extras_group(group, path)
  if type(group) ~= "table" then
    return false, path .. " must be a table"
  end
  if type(group.chars) ~= "table" or #group.chars == 0 then
    return false, path .. ".chars must be a non-empty array of single-character strings"
  end
  for i, ch in ipairs(group.chars) do
    if type(ch) ~= "string" then
      return false, path .. ".chars[" .. i .. "] must be a single-character string, got " .. type(ch)
    end
    if #ch ~= 1 then
      return false, path .. ".chars[" .. i .. "] = " .. vim.inspect(ch) .. ", expected a single-character string"
    end
  end
  if not VALID_HANDS[group.hand] then
    return false, path .. ".hand = " .. vim.inspect(group.hand) .. ", expected one of left/right/thumbs"
  end
  if not VALID_FINGERS[group.finger] then
    return false, path .. ".finger = " .. vim.inspect(group.finger) .. ", expected one of pinky/ring/middle/index/number/thumb"
  end
  if not VALID_ROWS[group.row] then
    return false, path .. ".row = " .. vim.inspect(group.row) .. ", expected one of outer/inner/center/number/thumb"
  end
  return true
end

--- Validate a layout table. Returns (ok, err_message).
--- err_message always names the field that failed so the author can find it.
local function validate(layout)
  if type(layout) ~= "table" then
    return false, "layout must be a table"
  end
  if type(layout.id) ~= "string" or layout.id == "" then
    return false, "layout.id must be a non-empty string"
  end
  if layout.display_name ~= nil and type(layout.display_name) ~= "string" then
    return false, "layout.display_name must be a string if present"
  end
  if type(layout.rows) ~= "table" then
    return false, "layout.rows must be a table with number/top/home/bottom arrays"
  end
  for _, row_name in ipairs(REQUIRED_ROW_NAMES) do
    local ok, err = validate_row_array(layout.rows[row_name], "layout.rows." .. row_name)
    if not ok then return false, err end
  end
  local ok, err = validate_row_array(layout.shifted_number_row, "layout.shifted_number_row")
  if not ok then return false, err end
  if layout.extras ~= nil then
    if type(layout.extras) ~= "table" then
      return false, "layout.extras must be an array of groups if present"
    end
    for i, group in ipairs(layout.extras) do
      local group_ok, group_err = validate_extras_group(group, "layout.extras[" .. i .. "]")
      if not group_ok then return false, group_err end
    end
  end
  return true
end

local function register(id, layout)
  local ok, err = validate(layout)
  if not ok then
    error("split-typer: invalid layout '" .. tostring(id) .. "': " .. err, 2)
  end
  available[id] = layout
end

register("qwerty", require("split-typer.layouts.qwerty"))
register("dvorak", require("split-typer.layouts.dvorak"))
register("colemak-dh", require("split-typer.layouts.colemak_dh"))

local function clear_table(t)
  for k in pairs(t) do t[k] = nil end
end

local function is_letter(ch)
  return ch:match("%a") ~= nil
end

local function set_meta(char_meta, ch, meta)
  char_meta[ch] = meta
  if is_letter(ch) then
    char_meta[ch:upper()] = meta
  end
end

local function build(layout)
  clear_table(M.char_meta)
  clear_table(M.chars_by_col)
  clear_table(M.center_left)
  clear_table(M.center_right)
  clear_table(M.cross_center_pairs)
  clear_table(M.shifted_number_symbols)

  local by_row = { number = {}, top = {}, home = {}, bottom = {} }
  local by_hand = { left = {}, right = {} }
  local center_left_list = {}
  local center_right_list = {}

  for _, row_name in ipairs(positions.letter_rows) do
    local glyphs = layout.rows[row_name]
    if glyphs then
      for col = 1, 10 do
        local ch = glyphs[col]
        if ch then
          local cmeta = positions.letter_column_meta[col]
          set_meta(M.char_meta, ch, { hand = cmeta.hand, finger = cmeta.finger, row = cmeta.row })
          table.insert(by_row[row_name], ch)
          table.insert(by_hand[cmeta.hand], ch)
          if col == positions.center_left_col then
            table.insert(center_left_list, ch)
            M.center_left[ch] = true
          elseif col == positions.center_right_col then
            table.insert(center_right_list, ch)
            M.center_right[ch] = true
          end
        end
      end
    end
  end

  local number_row = layout.rows.number or {}
  for col = 1, 10 do
    local ch = number_row[col]
    if ch then
      local meta = col <= positions.number_hand_split and positions.number_meta_left or positions.number_meta_right
      set_meta(M.char_meta, ch, meta)
      table.insert(by_row.number, ch)
    end
  end

  local shifted_numbers = layout.shifted_number_row or {}
  for col = 1, 10 do
    local ch = shifted_numbers[col]
    if ch then
      local meta = col <= positions.number_hand_split and positions.number_meta_left or positions.number_meta_right
      set_meta(M.char_meta, ch, meta)
      M.shifted_number_symbols[ch] = true
    end
  end

  for _, group in ipairs(layout.extras or {}) do
    local meta = { hand = group.hand, finger = group.finger, row = group.row }
    for _, ch in ipairs(group.chars) do
      set_meta(M.char_meta, ch, meta)
    end
  end

  for _, ch in ipairs(positions.thumb_chars) do
    M.char_meta[ch] = positions.thumb_meta
  end

  for i = 1, math.min(#center_left_list, #center_right_list) do
    local a = center_left_list[i]
    local b = center_right_list[i]
    M.cross_center_pairs[a:lower() .. b:lower()] = true
    M.cross_center_pairs[b:lower() .. a:lower()] = true
  end

  for col_name, col_indices in pairs(positions.columns) do
    local pieces = {}
    for _, row_name in ipairs(positions.letter_rows) do
      local glyphs = layout.rows[row_name]
      if glyphs then
        for _, c in ipairs(col_indices) do
          local ch = glyphs[c]
          if ch then table.insert(pieces, ch) end
        end
      end
    end
    M.chars_by_col[col_name] = table.concat(pieces)
  end

  M.chars_by_row.number = table.concat(by_row.number)
  M.chars_by_row.top    = table.concat(by_row.top)
  M.chars_by_row.home   = table.concat(by_row.home)
  M.chars_by_row.bottom = table.concat(by_row.bottom)
  M.chars_by_hand.left  = table.concat(by_hand.left)
  M.chars_by_hand.right = table.concat(by_hand.right)
  M.letter_chars = M.chars_by_hand.left .. M.chars_by_hand.right

  M.active = layout
end

--- Activate a layout. Accepts either a registered id (string) or a full
--- layout table (which will be validated and auto-registered under its `id`).
function M.rebuild(layout_or_id)
  local layout_or_id_arg = layout_or_id or "qwerty"
  local layout
  if type(layout_or_id_arg) == "table" then
    local ok, err = validate(layout_or_id_arg)
    if not ok then
      error("split-typer: invalid layout: " .. err, 2)
    end
    available[layout_or_id_arg.id] = layout_or_id_arg
    layout = layout_or_id_arg
  else
    layout = available[layout_or_id_arg]
    if not layout then
      error("split-typer: unknown layout '" .. tostring(layout_or_id_arg) .. "' (registered: " .. table.concat(M.available(), ", ") .. ")", 2)
    end
  end
  build(layout)
end

--- Register an additional layout by id. Validates before accepting.
function M.register(id, layout)
  register(id, layout)
end

--- Validate a layout table without registering it.
--- Returns (ok, err_message).
function M.validate(layout)
  return validate(layout)
end

--- Return the sorted list of registered layout ids.
function M.available()
  local ids = {}
  for id in pairs(available) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

M.rebuild("qwerty")

return M
