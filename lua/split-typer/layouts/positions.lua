-- Physical-grid conventions for a columnar split keyboard.
-- Nothing here is glyph- or layout-dependent: each entry describes the
-- finger/hand assignment for a physical key position on a 3x10 letter grid
-- plus the number row and thumb cluster.
--
-- The "row" label on each column meta is a column-group classification
-- ("outer" / "inner" / "center") used by the rest of the plugin as the
-- char_meta.row field. It is NOT a physical keyboard row index.

local M = {}

M.letter_column_meta = {
  { hand = "left",  finger = "pinky",  row = "outer"  },
  { hand = "left",  finger = "ring",   row = "outer"  },
  { hand = "left",  finger = "middle", row = "inner"  },
  { hand = "left",  finger = "index",  row = "center" },
  { hand = "left",  finger = "index",  row = "center" },
  { hand = "right", finger = "index",  row = "center" },
  { hand = "right", finger = "index",  row = "center" },
  { hand = "right", finger = "middle", row = "inner"  },
  { hand = "right", finger = "ring",   row = "outer"  },
  { hand = "right", finger = "pinky",  row = "outer"  },
}

M.center_left_col = 5
M.center_right_col = 6

M.number_hand_split = 5
M.number_meta_left  = { hand = "left",  finger = "number", row = "number" }
M.number_meta_right = { hand = "right", finger = "number", row = "number" }

M.columns = {
  l_pinky  = { 1 },
  l_ring   = { 2 },
  l_middle = { 3 },
  l_index  = { 4, 5 },
  r_index  = { 6, 7 },
  r_middle = { 8 },
  r_ring   = { 9 },
  r_pinky  = { 10 },
}

M.letter_rows = { "top", "home", "bottom" }

M.thumb_meta = { hand = "thumbs", finger = "thumb", row = "thumb" }
M.thumb_chars = { " ", "\n", "\t" }

return M
