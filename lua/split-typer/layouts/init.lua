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

local function register(id, layout)
  available[id] = layout
end

register("qwerty", require("split-typer.layouts.qwerty"))

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

--- Rebuild all derived tables for the given layout id.
--- Mutates M's tables in place so existing references stay valid.
function M.rebuild(layout_id)
  layout_id = layout_id or "qwerty"
  local layout = available[layout_id]
  if not layout then
    error("split-typer: unknown layout '" .. tostring(layout_id) .. "'")
  end
  build(layout)
end

--- Register an additional layout at runtime (used by layouts that ship with the plugin).
function M.register(id, layout)
  register(id, layout)
end

--- Return the list of registered layout ids.
function M.available()
  local ids = {}
  for id in pairs(available) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

M.rebuild("qwerty")

return M
