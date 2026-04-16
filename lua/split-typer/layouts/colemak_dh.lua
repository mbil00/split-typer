-- Colemak-DH matrix (a.k.a. Colemak Mod-DH, matrix variant) — the Colemak
-- variant designed for columnar split keyboards. Moves D, H, B, G, V, and M
-- into positions that suit an ortho/columnar grid, keeping index-finger work
-- off the awkward center-top reaches.
return {
  id = "colemak-dh",
  display_name = "Colemak-DH",
  rows = {
    number = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
    top    = { "q", "w", "f", "p", "b", "j", "l", "u", "y", ";" },
    home   = { "a", "r", "s", "t", "g", "m", "n", "e", "i", "o" },
    bottom = { "z", "x", "c", "d", "v", "k", "h", ",", ".", "/" },
  },
  shifted_number_row = { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" },
  extras = {
    -- Right-side reaches beyond column 10 (right pinky outer)
    { chars = { "[", "]", "'", "-", "=", "\\" },
      hand = "right", finger = "pinky", row = "outer" },
    -- Shifted forms of those extras
    { chars = { "{", "}", "\"", "_", "+", "|" },
      hand = "right", finger = "pinky", row = "outer" },
    -- Shifted forms of letter-grid punctuation on the right (`;,./` at cols 10, 8, 9, 10)
    { chars = { ":" },
      hand = "right", finger = "pinky", row = "outer" },
    { chars = { "<" },
      hand = "right", finger = "middle", row = "inner" },
    { chars = { ">" },
      hand = "right", finger = "ring", row = "outer" },
    { chars = { "?" },
      hand = "right", finger = "pinky", row = "outer" },
  },
}
