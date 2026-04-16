return {
  id = "dvorak",
  display_name = "Dvorak",
  rows = {
    number = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
    top    = { "'", ",", ".", "p", "y", "f", "g", "c", "r", "l" },
    home   = { "a", "o", "e", "u", "i", "d", "h", "t", "n", "s" },
    bottom = { ";", "q", "j", "k", "x", "b", "m", "w", "v", "z" },
  },
  shifted_number_row = { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" },
  extras = {
    -- Right-side reaches beyond column 10 (right pinky outer)
    { chars = { "[", "]", "/", "=", "-", "\\" },
      hand = "right", finger = "pinky", row = "outer" },
    -- Shifted forms of those right-side extras
    { chars = { "{", "}", "?", "+", "_", "|" },
      hand = "right", finger = "pinky", row = "outer" },
    -- Shifted forms of left-side letter-grid punctuation (' , . ; at cols 1-3)
    { chars = { "\"" },
      hand = "left", finger = "pinky", row = "outer" },
    { chars = { "<" },
      hand = "left", finger = "ring", row = "outer" },
    { chars = { ">" },
      hand = "left", finger = "middle", row = "inner" },
    { chars = { ":" },
      hand = "left", finger = "pinky", row = "outer" },
  },
}
