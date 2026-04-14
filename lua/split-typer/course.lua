local words = require("split-typer.words")

local M = {}

-- Course levels: progressive key introduction for Ergodox EZ columnar layout.
-- Each level adds new keys and requires minimum WPM + accuracy to pass.
-- req_max_errors: hard cap on errors regardless of accuracy percentage.
-- A long exercise can have high accuracy % but still 10+ errors - this prevents that.
M.levels = {
  {
    id = 1,
    name = "Home Row",
    new_chars = "asdfjkl;",
    all_chars = "asdfjkl;",
    description = "Find your home position on the columnar grid",
    req_wpm = 8,
    req_accuracy = 92,
    req_max_errors = 5,
    req_exercises = 3,
    words_range = { 10, 16 },
  },
  {
    id = 2,
    name = "+ E I",
    new_chars = "ei",
    all_chars = "asdfjkl;ei",
    description = "Middle fingers reach up to the top row",
    req_wpm = 10,
    req_accuracy = 92,
    req_max_errors = 5,
    req_exercises = 3,
    words_range = { 10, 18 },
  },
  {
    id = 3,
    name = "+ R U",
    new_chars = "ru",
    all_chars = "asdfjkl;eiru",
    description = "Index fingers reach up to the top row",
    req_wpm = 10,
    req_accuracy = 93,
    req_max_errors = 5,
    req_exercises = 3,
    words_range = { 12, 18 },
  },
  {
    id = 4,
    name = "+ G H",
    new_chars = "gh",
    all_chars = "asdfjkl;eirugh",
    description = "Index fingers reach inward - the split boundary",
    req_wpm = 10,
    req_accuracy = 92,
    req_max_errors = 5,
    req_exercises = 4,
    words_range = { 12, 18 },
  },
  {
    id = 5,
    name = "+ T Y",
    new_chars = "ty",
    all_chars = "asdfjkl;eirughty",
    description = "Center column top row - another split challenge",
    req_wpm = 12,
    req_accuracy = 93,
    req_max_errors = 4,
    req_exercises = 3,
    words_range = { 12, 20 },
  },
  {
    id = 6,
    name = "+ W O",
    new_chars = "wo",
    all_chars = "asdfjkl;eirughtywo",
    description = "Ring fingers reach up to the top row",
    req_wpm = 12,
    req_accuracy = 94,
    req_max_errors = 4,
    req_exercises = 3,
    words_range = { 12, 20 },
  },
  {
    id = 7,
    name = "+ Q P",
    new_chars = "qp",
    all_chars = "asdfjkl;eirughtywoqp",
    description = "Pinkies reach up - full top row complete",
    req_wpm = 14,
    req_accuracy = 94,
    req_max_errors = 4,
    req_exercises = 3,
    words_range = { 12, 20 },
  },
  {
    id = 8,
    name = "+ C V B",
    new_chars = "cvb",
    all_chars = "asdfjkl;eirughtywoqpcvb",
    description = "Left hand reaches down to the bottom row",
    req_wpm = 14,
    req_accuracy = 95,
    req_max_errors = 4,
    req_exercises = 3,
    words_range = { 14, 22 },
  },
  {
    id = 9,
    name = "+ N M ,",
    new_chars = "nm,",
    all_chars = "asdfjkl;eirughtywoqpcvbnm,",
    description = "Right hand reaches down to the bottom row",
    req_wpm = 15,
    req_accuracy = 95,
    req_max_errors = 3,
    req_exercises = 3,
    words_range = { 14, 22 },
  },
  {
    id = 10,
    name = "+ X Z . /",
    new_chars = "xz./",
    all_chars = "asdfjkl;eirughtywoqpcvbnm,xz./",
    description = "Complete the bottom row - all letter keys unlocked",
    req_wpm = 15,
    req_accuracy = 95,
    req_max_errors = 3,
    req_exercises = 4,
    words_range = { 14, 22 },
  },
  {
    id = 11,
    name = "Numbers",
    new_chars = "1234567890",
    all_chars = "asdfjkl;eirughtywoqpcvbnm,xz./1234567890",
    description = "Top row numbers on the columnar grid",
    req_wpm = 14,
    req_accuracy = 94,
    req_max_errors = 4,
    req_exercises = 4,
    words_range = { 12, 18 },
  },
  {
    id = 12,
    name = "Full Mastery",
    new_chars = "!@#$%^&*()-_=+[]{}|;:'\"<>?",
    all_chars = "asdfjkl;eirughtywoqpcvbnm,xz./1234567890!@#$%^&*()-_=+[]{}|;:'\"<>?",
    description = "All keys - prove your mastery of the split keyboard",
    req_wpm = 16,
    req_accuracy = 96,
    req_max_errors = 3,
    req_exercises = 5,
    words_range = { 14, 22 },
  },
}

-- Progress persistence
local data_dir = vim.fn.stdpath("data") .. "/split-typer"
local progress_file = data_dir .. "/progress.json"

local _progress = nil

--- Load progress from disk.
--- @return table
function M.load_progress()
  if _progress then
    return _progress
  end

  local f = io.open(progress_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
      local ok, data = pcall(vim.json.decode, content)
      if ok and type(data) == "table" then
        _progress = data
        return _progress
      end
    end
  end

  _progress = { current_level = 1, levels = {} }
  return _progress
end

--- Save progress to disk.
function M.save_progress()
  if not _progress then
    return
  end
  vim.fn.mkdir(data_dir, "p")
  local f = io.open(progress_file, "w")
  if f then
    f:write(vim.json.encode(_progress))
    f:close()
  end
end

--- Get progress for a specific level.
--- @param level_id number
--- @return { completed: number, best_wpm: number, best_accuracy: number, passed: boolean }
function M.get_level_progress(level_id)
  local prog = M.load_progress()
  local key = tostring(level_id)
  if not prog.levels[key] then
    prog.levels[key] = { completed = 0, best_wpm = 0, best_accuracy = 0, passed = false }
  end
  return prog.levels[key]
end

--- Record a completed exercise and check if the level is now passed.
--- @param level_id number
--- @param wpm number
--- @param accuracy number
--- @param errors number Total error keystrokes
--- @return boolean passed Whether this exercise counts toward passing
--- @return boolean level_complete Whether the level is now fully passed
function M.record_exercise(level_id, wpm, accuracy, errors)
  local level = M.get_level(level_id)
  if not level then
    return false, false
  end

  local prog = M.get_level_progress(level_id)

  -- Update best scores regardless
  if wpm > prog.best_wpm then
    prog.best_wpm = wpm
  end
  if accuracy > prog.best_accuracy then
    prog.best_accuracy = accuracy
  end

  -- Check if this exercise meets ALL passing requirements:
  -- 1. Minimum WPM
  -- 2. Minimum accuracy percentage
  -- 3. Maximum error count (hard cap)
  local max_errors = level.req_max_errors or 5
  local passed_exercise = wpm >= level.req_wpm
    and accuracy >= level.req_accuracy
    and errors <= max_errors
  if passed_exercise then
    prog.completed = prog.completed + 1
  end

  -- Check if level is now complete
  local level_complete = false
  if not prog.passed and prog.completed >= level.req_exercises then
    prog.passed = true
    level_complete = true
    -- Advance current level
    local progress = M.load_progress()
    if progress.current_level == level_id and level_id < #M.levels then
      progress.current_level = level_id + 1
    end
  end

  M.save_progress()
  return passed_exercise, level_complete
end

--- Check if a level is unlocked.
--- @param level_id number
--- @return boolean
function M.is_unlocked(level_id)
  if level_id == 1 then
    return true
  end
  local prev = M.get_level_progress(level_id - 1)
  return prev.passed
end

--- Get level definition by ID.
--- @param level_id number
--- @return table|nil
function M.get_level(level_id)
  for _, lvl in ipairs(M.levels) do
    if lvl.id == level_id then
      return lvl
    end
  end
  return nil
end

--- Get the current (highest unlocked) level ID.
--- @return number
function M.get_current_level()
  local prog = M.load_progress()
  return prog.current_level or 1
end

--- Generate a random exercise for a course level.
--- @param level_id number
--- @return string
function M.generate_exercise(level_id)
  local level = M.get_level(level_id)
  if not level then
    return "error: level not found"
  end

  -- For the final level with symbols, generate a mixed exercise
  if level_id == #M.levels then
    return generate_mastery_exercise(level)
  end

  return words.generate({
    chars = level.all_chars,
    focus_chars = level.new_chars,
    min_words = level.words_range[1],
    max_words = level.words_range[2],
  })
end

--- Generate a mastery exercise that includes symbols, numbers, and words.
function generate_mastery_exercise(level)
  -- Mix of words, number sequences, and symbol patterns
  local parts = {}
  local num_parts = math.random(12, 18)

  local symbol_patterns = {
    "()", "{}", "[]", "<>", "!=", "==", "+=", "->", "=>", "||",
    "&&", "<=", ">=", "++", "--", "::", "..", "**", "//", "??",
    "#{}", "${}", "[0]", "(i)", "{k: v}", "a[i]", "f(x)", "!ok",
    "a + b", "x - y", "n * m", "p / q", "i % 2", "a ^ b",
    "@name", "#tag", "$val", "&ref", "*ptr",
  }

  local number_patterns = {
    "42", "100", "255", "1024", "8080", "3.14", "0xff", "1e10",
    "192.168.1.1", "127.0.0.1", "80/tcp", "v2.1", "2026-04-14",
  }

  for i = 1, num_parts do
    local roll = math.random()
    if roll < 0.55 then
      -- Regular word
      local pool = words.filter("abcdefghijklmnopqrstuvwxyz")
      if #pool > 0 then
        parts[i] = pool[math.random(1, #pool)]
      else
        parts[i] = words.combo("abcdefghijklmnopqrstuvwxyz", math.random(3, 6))
      end
    elseif roll < 0.78 then
      -- Symbol pattern
      parts[i] = symbol_patterns[math.random(1, #symbol_patterns)]
    else
      -- Number pattern
      parts[i] = number_patterns[math.random(1, #number_patterns)]
    end
  end

  return table.concat(parts, " ")
end

--- Reset all course progress.
function M.reset_progress()
  _progress = { current_level = 1, levels = {} }
  M.save_progress()
end

return M
