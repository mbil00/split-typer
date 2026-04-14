local exercises = require("split-typer.exercises")
local course = require("split-typer.course")
local errs = require("split-typer.errors")

local M = {}

-- State
local state = {
  buf = nil,
  win = nil,
  ns = nil,
  timer = nil,
  screen = nil, -- "menu", "exercise", "results", "course", "course_results"
  category_id = nil,
  exercise_idx = nil,
  -- Mode: "freeplay" or "course"
  mode = "freeplay",
  course_level = nil,
  -- Session state
  target = nil,
  char_map = nil,
  input = {},
  pos = 0,
  error_count = 0,
  keystroke_count = 0,
  start_time = nil,
  end_time = nil,
  finished = false,
  no_backspace = false,
  streak = 0,
  best_streak = 0,
  error_log = {},
  -- Stats display extmark id
  header_extmark = nil,
}

-- Highlight groups
local function setup_highlights()
  local hl = vim.api.nvim_set_hl
  hl(0, "SplitTyperCorrect", { fg = "#a6e3a1", bold = true, default = true })
  hl(0, "SplitTyperError", { fg = "#1e1e2e", bg = "#f38ba8", bold = true, default = true })
  hl(0, "SplitTyperCursor", { bg = "#585b70", underline = true, default = true })
  hl(0, "SplitTyperPending", { fg = "#6c7086", default = true })
  hl(0, "SplitTyperHeader", { fg = "#89b4fa", bold = true, default = true })
  hl(0, "SplitTyperStats", { fg = "#bac2de", default = true })
  hl(0, "SplitTyperGood", { fg = "#a6e3a1", bold = true, default = true })
  hl(0, "SplitTyperOk", { fg = "#f9e2af", bold = true, default = true })
  hl(0, "SplitTyperBad", { fg = "#f38ba8", bold = true, default = true })
  hl(0, "SplitTyperSep", { fg = "#45475a", default = true })
  hl(0, "SplitTyperMenuKey", { fg = "#f9e2af", bold = true, default = true })
  hl(0, "SplitTyperMenuText", { fg = "#cdd6f4", default = true })
  hl(0, "SplitTyperMenuDesc", { fg = "#6c7086", italic = true, default = true })
  hl(0, "SplitTyperTitle", { fg = "#cba6f7", bold = true, default = true })
  hl(0, "SplitTyperEnter", { fg = "#f9e2af", italic = true, default = true })
  hl(0, "SplitTyperScore", { fg = "#f5c2e7", bold = true, default = true })
  hl(0, "SplitTyperProgress", { fg = "#89b4fa", default = true })
  hl(0, "SplitTyperProgressBg", { fg = "#313244", default = true })
end

-- Build character map from target text
-- Maps flat position -> { char, line, col, is_newline }
local function build_char_map(text)
  local chars = {}
  local lines = vim.split(text, "\n")
  local flat_pos = 0
  for line_idx, line in ipairs(lines) do
    for col_idx = 1, #line do
      flat_pos = flat_pos + 1
      chars[flat_pos] = {
        char = line:sub(col_idx, col_idx),
        line = line_idx - 1,
        col = col_idx - 1,
        is_newline = false,
      }
    end
    if line_idx < #lines then
      flat_pos = flat_pos + 1
      chars[flat_pos] = {
        char = "\n",
        line = line_idx - 1,
        col = #line,
        is_newline = true,
      }
    end
  end
  return chars
end

-- Get current stats
local function get_stats()
  if not state.start_time then
    return { wpm = 0, accuracy = 100, time = 0, score = 0, errors = 0, streak = 0, best_streak = 0, total_chars = 0, typed_chars = 0, keystrokes = 0 }
  end

  local end_t = state.end_time or vim.uv.hrtime()
  local elapsed = (end_t - state.start_time) / 1e9

  local correct = 0
  for i = 1, state.pos do
    if state.input[i] == state.char_map[i].char then
      correct = correct + 1
    end
  end

  local accuracy = state.pos > 0 and (correct / state.pos * 100) or 100
  local wpm = elapsed > 0 and ((state.pos / 5) / (elapsed / 60)) or 0
  local score = math.floor(wpm * (accuracy / 100) * (accuracy / 100))

  return {
    wpm = math.floor(wpm),
    accuracy = math.floor(accuracy * 10) / 10,
    time = elapsed,
    score = score,
    errors = state.error_count,
    correct = correct,
    total_chars = #state.char_map,
    typed_chars = state.pos,
    keystrokes = state.keystroke_count,
    streak = state.streak,
    best_streak = state.best_streak,
  }
end

-- Format time as M:SS
local function format_time(seconds)
  local m = math.floor(seconds / 60)
  local s = math.floor(seconds % 60)
  return string.format("%d:%02d", m, s)
end

-- Create or get floating window
local function ensure_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    return
  end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "split-typer"
  end

  state.ns = vim.api.nvim_create_namespace("split_typer")

  local width = math.min(math.floor(vim.o.columns * 0.85), 100)
  local height = math.min(math.floor(vim.o.lines * 0.8), 40)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
    title = " Split Typer ",
    title_pos = "center",
  })

  vim.wo[state.win].wrap = true
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"

  -- Cleanup on buffer delete
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = state.buf,
    once = true,
    callback = function()
      M.cleanup()
    end,
  })
end

-- Close everything
function M.cleanup()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.ns = nil
  state.screen = nil
end

-- Clear buffer and keymaps
local function clear_buffer()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  -- Clear namespace
  if state.ns then
    vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  end
  -- Make modifiable to clear
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
  -- Clear all buffer-local keymaps by re-creating the buffer concept
  -- (We'll set new keymaps for each screen)
end

-- Map a key in the current buffer (normal mode)
local function map(key, fn)
  vim.keymap.set("n", key, fn, { buffer = state.buf, nowait = true, silent = true })
end

-- Clear all buffer-local keymaps
local function clear_keymaps()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local all_keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    .. "`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/? "
  for j = 1, #all_keys do
    local c = all_keys:sub(j, j)
    local lhs = c
    if c == " " then
      lhs = "<Space>"
    elseif c == "|" then
      lhs = "<Bar>"
    elseif c == "\\" then
      lhs = "<Bslash>"
    elseif c == "<" then
      lhs = "<lt>"
    end
    pcall(vim.keymap.del, "n", lhs, { buffer = state.buf })
  end
  for _, k in ipairs({ "<CR>", "<BS>", "<Tab>", "<Esc>", "<C-c>", "<Up>", "<Down>", "<Left>", "<Right>", "<C-w>" }) do
    pcall(vim.keymap.del, "n", k, { buffer = state.buf })
  end
end

-- Set up character keymaps for typing exercise
local function setup_typing_keymaps()
  -- Map all printable ASCII characters
  local chars = "abcdefghijklmnopqrstuvwxyz"
    .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    .. "0123456789"
    .. "`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/? "

  for i = 1, #chars do
    local c = chars:sub(i, i)
    local lhs = c
    if c == " " then
      lhs = "<Space>"
    elseif c == "|" then
      lhs = "<Bar>"
    elseif c == "\\" then
      lhs = "<Bslash>"
    elseif c == "<" then
      lhs = "<lt>"
    end
    map(lhs, function()
      handle_typed_char(c)
    end)
  end

  map("<CR>", function()
    handle_typed_char("\n")
  end)
  map("<BS>", function()
    if state.no_backspace then
      show_no_backspace_flash()
    else
      handle_backspace()
    end
  end)
  map("<Tab>", function()
    handle_typed_char("\t")
  end)
  map("<Esc>", function()
    if state.mode == "course" then
      M.show_course()
    else
      M.show_menu()
    end
  end)
  map("<C-c>", function()
    M.cleanup()
  end)

  -- Disable arrow keys and common normal mode keys
  for _, k in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>", "<C-w>" }) do
    map(k, function() end)
  end
end

-- Brief flash when user tries backspace in no-backspace mode
local _flash_extmark = nil
function show_no_backspace_flash()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local flash_ns = vim.api.nvim_create_namespace("split_typer_flash")
  vim.api.nvim_buf_clear_namespace(state.buf, flash_ns, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(state.buf)
  _flash_extmark = vim.api.nvim_buf_set_extmark(state.buf, flash_ns, line_count - 1, 0, {
    virt_lines = {
      { { "" , "" } },
      { { "  BACKSPACE DISABLED - commit to every keystroke", "SplitTyperBad" } },
    },
  })
  vim.defer_fn(function()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      vim.api.nvim_buf_clear_namespace(state.buf, flash_ns, 0, -1)
    end
  end, 1200)
end

-- Handle a typed character during exercise
function handle_typed_char(char)
  if state.finished then
    return
  end
  if state.pos >= #state.char_map then
    return
  end

  -- Start timer on first keypress
  if not state.start_time then
    state.start_time = vim.uv.hrtime()
    start_stats_timer()
  end

  state.keystroke_count = state.keystroke_count + 1
  state.pos = state.pos + 1
  state.input[state.pos] = char

  local expected = state.char_map[state.pos].char
  if char ~= expected then
    state.error_count = state.error_count + 1
    state.streak = 0
    state.error_log[#state.error_log + 1] = {
      expected = expected,
      actual = char,
      pos = state.pos,
    }
  else
    state.streak = state.streak + 1
    if state.streak > state.best_streak then
      state.best_streak = state.streak
    end
  end

  -- Check if exercise is complete
  if state.pos >= #state.char_map then
    state.finished = true
    state.end_time = vim.uv.hrtime()
    if state.timer then
      state.timer:stop()
    end
    -- Short delay then show results
    vim.defer_fn(function()
      save_stats()
      if state.mode == "course" then
        M.show_course_results()
      else
        M.show_results()
      end
    end, 300)
  end

  update_exercise_display()
end

-- Handle backspace during exercise
function handle_backspace()
  if state.finished then
    return
  end
  if state.pos <= 0 then
    return
  end

  state.keystroke_count = state.keystroke_count + 1
  state.input[state.pos] = nil
  state.pos = state.pos - 1

  update_exercise_display()
end

-- Start the stats update timer
function start_stats_timer()
  if state.timer then
    state.timer:stop()
    state.timer:close()
  end
  state.timer = vim.uv.new_timer()
  state.timer:start(
    500,
    500,
    vim.schedule_wrap(function()
      if state.screen == "exercise" and not state.finished then
        update_stats_header()
      end
    end)
  )
end

-- Update just the stats header (called by timer)
function update_stats_header()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  if not state.ns then
    return
  end

  local stats = get_stats()
  local cat = exercises.get_category(state.category_id)
  local cat_name = cat and cat.name or "?"
  local progress = string.format("%d/%d", state.pos, #state.char_map)

  -- Delete old header extmark and recreate
  if state.header_extmark then
    pcall(vim.api.nvim_buf_del_extmark, state.buf, state.ns, state.header_extmark)
  end

  local wpm_hl = "SplitTyperStats"
  if stats.wpm >= 60 then
    wpm_hl = "SplitTyperGood"
  elseif stats.wpm >= 30 then
    wpm_hl = "SplitTyperOk"
  end

  local acc_hl = "SplitTyperStats"
  if stats.accuracy >= 95 then
    acc_hl = "SplitTyperGood"
  elseif stats.accuracy >= 80 then
    acc_hl = "SplitTyperOk"
  else
    acc_hl = "SplitTyperBad"
  end

  -- Title line
  local title_line = {
    { " " .. cat_name, "SplitTyperHeader" },
    { "  ", "" },
    { progress, "SplitTyperProgress" },
  }
  if state.no_backspace then
    title_line[#title_line + 1] = { "    NO BACKSPACE", "SplitTyperBad" }
  end

  -- Stats line
  local stats_line = {
    { " WPM: ", "SplitTyperSep" },
    { tostring(stats.wpm), wpm_hl },
    { "  Acc: ", "SplitTyperSep" },
    { string.format("%.1f%%", stats.accuracy), acc_hl },
    { "  Err: ", "SplitTyperSep" },
    { tostring(stats.errors), stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood" },
    { "  Streak: ", "SplitTyperSep" },
    { tostring(stats.streak), stats.streak >= 10 and "SplitTyperGood" or "SplitTyperStats" },
    { string.format(" (best: %d)", stats.best_streak), "SplitTyperPending" },
  }

  state.header_extmark = vim.api.nvim_buf_set_extmark(state.buf, state.ns, 0, 0, {
    id = state.header_extmark,
    virt_lines_above = true,
    virt_lines = {
      title_line,
      stats_line,
      {
        { " " .. string.rep("\u{2500}", 60), "SplitTyperSep" },
      },
      { { "", "" } },
    },
  })
end

-- Update the full exercise display (highlights + header)
function update_exercise_display()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  if not state.ns then
    return
  end

  -- Clear character highlights (but not the header extmark)
  -- We'll clear all and re-add header
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  state.header_extmark = nil

  -- Build highlight runs
  local runs = {}
  for i = 1, #state.char_map do
    local entry = state.char_map[i]
    if entry.is_newline then
      goto continue
    end

    local hl
    if i <= state.pos then
      if state.input[i] == entry.char then
        hl = "SplitTyperCorrect"
      else
        hl = "SplitTyperError"
      end
    elseif i == state.pos + 1 then
      hl = "SplitTyperCursor"
    else
      hl = "SplitTyperPending"
    end

    -- Try to extend the last run
    local last = runs[#runs]
    if last and last.line == entry.line and last.hl == hl and last.col_end == entry.col then
      last.col_end = entry.col + 1
    else
      runs[#runs + 1] = {
        line = entry.line,
        col_start = entry.col,
        col_end = entry.col + 1,
        hl = hl,
      }
    end

    ::continue::
  end

  -- Apply highlight runs
  for _, run in ipairs(runs) do
    vim.api.nvim_buf_set_extmark(state.buf, state.ns, run.line, run.col_start, {
      end_col = run.col_end,
      hl_group = run.hl,
    })
  end

  -- Add newline indicators
  for i = 1, #state.char_map do
    local entry = state.char_map[i]
    if entry.is_newline then
      local hl = "SplitTyperPending"
      local symbol = "\u{21b5}"
      if i <= state.pos then
        if state.input[i] == "\n" then
          hl = "SplitTyperCorrect"
        else
          hl = "SplitTyperError"
        end
      elseif i == state.pos + 1 then
        hl = "SplitTyperEnter"
        symbol = "\u{21b5} Enter"
      end
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, entry.line, entry.col, {
        virt_text = { { " " .. symbol, hl } },
        virt_text_pos = "inline",
      })
    end
  end

  -- Move cursor to current position
  if state.pos < #state.char_map then
    local entry = state.char_map[state.pos + 1]
    local cursor_line = entry.line
    local cursor_col = entry.col
    if entry.is_newline then
      -- Place cursor at end of line
      local lines = vim.api.nvim_buf_get_lines(state.buf, entry.line, entry.line + 1, false)
      cursor_col = lines[1] and #lines[1] or 0
    end
    pcall(vim.api.nvim_win_set_cursor, state.win, { cursor_line + 1, cursor_col })
  end

  -- Update header
  update_stats_header()
end

-- ============================================================
-- Course mode
-- ============================================================

-- Show the course level selection screen
function M.show_course()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  state.screen = "course"
  state.mode = "course"
  ensure_window()
  clear_buffer()

  local levels = course.levels
  local cur = course.get_current_level()

  local lines = {}
  local highlights = {}

  table.insert(lines, "")
  table.insert(lines, "       TOUCH TYPING COURSE")
  table.insert(lines, "       Structured progression for split keyboard mastery")
  table.insert(lines, "")
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }

  local sep = string.rep("\u{2500}", 70)
  table.insert(lines, sep)
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  table.insert(lines, "")

  local level_keys = {}

  for _, lvl in ipairs(levels) do
    local prog = course.get_level_progress(lvl.id)
    local unlocked = course.is_unlocked(lvl.id)
    local key = lvl.id < 10 and tostring(lvl.id) or (lvl.id == 10 and "0" or string.char(86 + lvl.id))
    -- 10->0, 11->a, 12->b
    if lvl.id == 10 then
      key = "0"
    elseif lvl.id == 11 then
      key = "a"
    elseif lvl.id == 12 then
      key = "b"
    end

    local status, status_hl
    if prog.passed then
      status = string.format("PASSED  (best: %d WPM, %.0f%%)", prog.best_wpm, prog.best_accuracy)
      status_hl = "SplitTyperGood"
    elseif unlocked then
      local done = prog.completed
      local need = lvl.req_exercises
      local me = lvl.req_max_errors or 5
      status = string.format("%d/%d done  (need: %d WPM, %.0f%%, <%d err)", done, need, lvl.req_wpm, lvl.req_accuracy, me + 1)
      status_hl = "SplitTyperOk"
    else
      status = "LOCKED"
      status_hl = "SplitTyperPending"
    end

    local marker = " "
    if lvl.id == cur and not prog.passed then
      marker = ">"
    end

    local line
    if unlocked then
      line = string.format(" %s[%s]  %-18s [%s]", marker, key, lvl.name, lvl.new_chars)
      level_keys[key] = lvl.id
    else
      line = string.format("  -   %-18s [%s]", lvl.name, lvl.new_chars)
    end

    -- Pad to align status
    line = line .. string.rep(" ", math.max(0, 44 - #line)) .. status

    table.insert(lines, line)
    local li = #lines - 1

    -- Key highlight
    if unlocked then
      local key_start = marker == ">" and 2 or 2
      highlights[#highlights + 1] = { li, key_start, key_start + 3, "SplitTyperMenuKey" }
    end
    -- Status highlight
    local status_start = #line - #status
    highlights[#highlights + 1] = { li, status_start, #line, status_hl }
    -- Current level marker
    if marker == ">" then
      highlights[#highlights + 1] = { li, 0, 1, "SplitTyperOk" }
    end
  end

  table.insert(lines, "")
  local sep2 = string.rep("\u{2500}", 70)
  table.insert(lines, sep2)
  highlights[#highlights + 1] = { #lines - 1, 0, #sep2, "SplitTyperSep" }
  table.insert(lines, "")
  table.insert(lines, "  Press a number to start that level")
  table.insert(lines, "  [Esc] Back to menu    [q] Quit    [R] Reset progress")

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  -- Apply highlights
  if state.ns then
    for _, h in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  -- Keymaps
  clear_keymaps()

  for key, level_id in pairs(level_keys) do
    map(key, function()
      M.start_course_exercise(level_id)
    end)
  end

  map("<Esc>", function()
    M.show_menu()
  end)
  map("q", function()
    M.cleanup()
  end)
  map("<C-c>", function()
    M.cleanup()
  end)
  map("R", function()
    course.reset_progress()
    M.show_course()
  end)
end

-- Start a course exercise for a given level
function M.start_course_exercise(level_id)
  if not course.is_unlocked(level_id) then
    return
  end

  state.mode = "course"
  state.course_level = level_id
  state.screen = "exercise"

  local text = course.generate_exercise(level_id)
  local level = course.get_level(level_id)

  state.target = text
  state.char_map = build_char_map(text)
  state.category_id = "course_" .. level_id
  state.exercise_idx = nil
  state.no_backspace = false
  state.input = {}
  state.pos = 0
  state.error_count = 0
  state.keystroke_count = 0
  state.start_time = nil
  state.end_time = nil
  state.finished = false
  state.streak = 0
  state.best_streak = 0
  state.error_log = {}
  state.header_extmark = nil

  ensure_window()
  clear_buffer()

  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  setup_typing_keymaps()
  update_exercise_display()
end

-- Show course results after completing a course exercise
function M.show_course_results()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  state.screen = "course_results"
  ensure_window()
  clear_buffer()

  local stats = get_stats()
  local level_id = state.course_level
  local level = course.get_level(level_id)

  -- Record the exercise and check pass status
  local passed_exercise, level_complete = course.record_exercise(level_id, stats.wpm, stats.accuracy, stats.errors)
  local prog = course.get_level_progress(level_id)

  -- Build the results display
  local lines = {}
  local highlights = {}

  table.insert(lines, "")

  local max_errors = level.req_max_errors or 5

  if level_complete then
    table.insert(lines, "       LEVEL COMPLETE!")
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif passed_exercise then
    table.insert(lines, "       EXERCISE PASSED")
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperOk" }
  else
    table.insert(lines, "       NOT YET...")
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperBad" }
  end

  table.insert(lines, string.format("       Level %d: %s", level_id, level.name))
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperHeader" }

  -- Show specific failure reasons
  if not passed_exercise then
    local reasons = {}
    if stats.wpm < level.req_wpm then
      reasons[#reasons + 1] = string.format("WPM too low (%d < %d)", stats.wpm, level.req_wpm)
    end
    if stats.accuracy < level.req_accuracy then
      reasons[#reasons + 1] = string.format("Accuracy too low (%.1f%% < %.0f%%)", stats.accuracy, level.req_accuracy)
    end
    if stats.errors > max_errors then
      reasons[#reasons + 1] = string.format("Too many errors (%d > %d max)", stats.errors, max_errors)
    end
    if #reasons > 0 then
      local reason_line = "       " .. table.concat(reasons, " | ")
      table.insert(lines, reason_line)
      highlights[#highlights + 1] = { #lines - 1, 0, #reason_line, "SplitTyperBad" }
    end
  end

  table.insert(lines, "")

  local sep = string.rep("\u{2500}", 50)
  table.insert(lines, sep)
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  table.insert(lines, "")

  -- Stats
  local wpm_line = string.format("    WPM:         %d", stats.wpm)
  local acc_line = string.format("    Accuracy:    %.1f%%", stats.accuracy)
  local err_line = string.format("    Errors:      %d", stats.errors)
  local time_line = string.format("    Time:        %s", format_time(stats.time))
  table.insert(lines, wpm_line)
  table.insert(lines, acc_line)
  table.insert(lines, err_line)
  table.insert(lines, time_line)

  local wpm_hl = stats.wpm >= level.req_wpm and "SplitTyperGood" or "SplitTyperBad"
  local acc_hl = stats.accuracy >= level.req_accuracy and "SplitTyperGood" or "SplitTyperBad"
  local err_hl = stats.errors <= max_errors and "SplitTyperGood" or "SplitTyperBad"
  highlights[#highlights + 1] = { #lines - 4, 17, #wpm_line, wpm_hl }
  highlights[#highlights + 1] = { #lines - 3, 17, #acc_line, acc_hl }
  highlights[#highlights + 1] = { #lines - 2, 17, #err_line, err_hl }

  table.insert(lines, "")

  -- Requirements
  local req_line = string.format("    Required:    %d WPM, %.0f%% acc, %d max errors", level.req_wpm, level.req_accuracy, max_errors)
  table.insert(lines, req_line)
  highlights[#highlights + 1] = { #lines - 1, 17, #req_line, "SplitTyperSep" }

  local prog_line = string.format("    Progress:    %d/%d exercises passed", prog.completed, level.req_exercises)
  table.insert(lines, prog_line)
  local prog_hl = prog.passed and "SplitTyperGood" or "SplitTyperOk"
  highlights[#highlights + 1] = { #lines - 1, 17, #prog_line, prog_hl }

  if prog.best_wpm > 0 then
    local best_line = string.format("    Best:        %d WPM, %.0f%% accuracy", prog.best_wpm, prog.best_accuracy)
    table.insert(lines, best_line)
    highlights[#highlights + 1] = { #lines - 1, 17, #best_line, "SplitTyperScore" }
  end

  table.insert(lines, "")
  local sep2 = string.rep("\u{2500}", 50)
  table.insert(lines, sep2)
  highlights[#highlights + 1] = { #lines - 1, 0, #sep2, "SplitTyperSep" }
  table.insert(lines, "")

  -- Navigation
  if level_complete and level_id < #course.levels then
    table.insert(lines, "    [n] Start next level")
  else
    table.insert(lines, "    [n] Next exercise (same level)")
  end
  table.insert(lines, "    [r] Retry (new random exercise)")
  table.insert(lines, "    [c] Back to course")
  table.insert(lines, "    [q] Quit")

  -- Highlight nav keys
  for li = #lines - 4, #lines - 1 do
    highlights[#highlights + 1] = { li, 4, 7, "SplitTyperMenuKey" }
  end

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  if state.ns then
    for _, h in ipairs(highlights) do
      pcall(vim.api.nvim_buf_set_extmark, state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  -- Keymaps
  clear_keymaps()

  map("n", function()
    if level_complete and level_id < #course.levels then
      M.start_course_exercise(level_id + 1)
    else
      M.start_course_exercise(level_id)
    end
  end)
  map("r", function()
    M.start_course_exercise(level_id)
  end)
  map("c", function()
    M.show_course()
  end)
  map("<Esc>", function()
    M.show_course()
  end)
  map("q", function()
    M.cleanup()
  end)
  map("<C-c>", function()
    M.cleanup()
  end)
end

-- ============================================================
-- Free-play mode
-- ============================================================

-- Menu section definitions for grouping categories
local menu_sections = {
  { title = "General", pattern = "^home_row$|^left_hand$|^right_hand$|^center_column$|^common_words$" },
  { title = "Characters", pattern = "^numbers$|^symbols$|^brackets$" },
  { title = "Code", pattern = "^code_" },
  { title = "Text", pattern = "^prose$|^mixed$" },
  { title = "Precision (no backspace)", pattern = "^precision_" },
  { title = "Finger Isolation", pattern = "^finger_" },
}

-- Assign a category to a section
local function get_section(cat_id)
  for _, sec in ipairs(menu_sections) do
    for part in sec.pattern:gmatch("[^|]+") do
      local pat = part:gsub("^%^", ""):gsub("%$$", "")
      if pat:sub(-1) == "_" then
        -- prefix match
        if cat_id:sub(1, #pat) == pat then
          return sec.title
        end
      else
        if cat_id == pat then
          return sec.title
        end
      end
    end
  end
  return "Other"
end

-- Show the category selection menu
function M.show_menu()
  -- Stop timer if running
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  state.screen = "menu"
  state.mode = "freeplay"
  ensure_window()
  clear_buffer()

  local cats = exercises.get_categories()

  -- Build ordered groups
  local groups = {}
  local group_order = {}
  for _, cat in ipairs(cats) do
    local sec = get_section(cat.id)
    if not groups[sec] then
      groups[sec] = {}
      group_order[#group_order + 1] = sec
    end
    groups[sec][#groups[sec] + 1] = cat
  end

  -- Assign keys: 1-9, 0, a-z (skip reserved keys)
  local reserved = { q = true, c = true, s = true, t = true }
  local key_pool = {}
  for i = 1, 9 do
    key_pool[#key_pool + 1] = tostring(i)
  end
  key_pool[#key_pool + 1] = "0"
  for ch_code = string.byte("a"), string.byte("z") do
    local ch = string.char(ch_code)
    if not reserved[ch] then
      key_pool[#key_pool + 1] = ch
    end
  end

  local key_idx = 0
  local cat_keys = {} -- cat.id -> key

  local lines = {}
  local highlights = {} -- { line_idx (0-based), col_start, col_end, hl_group }

  table.insert(lines, "")
  table.insert(lines, "       SPLIT TYPER")
  table.insert(lines, "       Ergodox EZ Practice")
  table.insert(lines, "")

  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }

  -- Course entry at the top
  local cur_level = course.get_current_level()
  local cur_lvl = course.get_level(cur_level)
  local cur_prog = course.get_level_progress(cur_level)
  local course_status
  if cur_prog.passed and cur_level == #course.levels then
    course_status = "All levels complete!"
  else
    course_status = string.format("Level %d: %s (%d/%d)", cur_level, cur_lvl.name, cur_prog.completed, cur_lvl.req_exercises)
  end

  local course_sep = " " .. string.rep("\u{2500}", 3) .. " Course " .. string.rep("\u{2500}", 34)
  table.insert(lines, course_sep)
  highlights[#highlights + 1] = { #lines - 1, 0, #course_sep, "SplitTyperSep" }
  table.insert(lines, "")

  local course_line = string.format("  [c]  %-28s %s", "Touch Typing Course", course_status)
  table.insert(lines, course_line)
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #course_line, "SplitTyperMenuDesc" }

  -- Weak key practice (from error analysis)
  local targeted_desc = "(not enough data yet)"
  local targeted_enabled = errs.has_enough_data()
  if targeted_enabled then
    local worst = errs.get_worst_chars(3, 15)
    if #worst > 0 then
      local parts = {}
      for _, wc in ipairs(worst) do
        parts[#parts + 1] = string.format("'%s' %.0f%%", wc.char, wc.error_rate * 100)
      end
      targeted_desc = "Targeting: " .. table.concat(parts, ", ")
    end
  end
  local targeted_line = string.format("  [t]  %-28s %s", "Weak Key Practice", targeted_desc)
  table.insert(lines, targeted_line)
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #targeted_line, "SplitTyperMenuDesc" }

  -- Stats dashboard
  local dash_line = string.format("  [s]  %-28s %s", "Stats Dashboard", "View your typing profile")
  table.insert(lines, dash_line)
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #dash_line, "SplitTyperMenuDesc" }

  table.insert(lines, "")

  -- Free play categories
  for _, sec_name in ipairs(group_order) do
    local sep = " " .. string.rep("\u{2500}", 3) .. " " .. sec_name .. " " .. string.rep("\u{2500}", 40 - #sec_name)
    table.insert(lines, sep)
    highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
    table.insert(lines, "")

    for _, cat in ipairs(groups[sec_name]) do
      key_idx = key_idx + 1
      local key = key_pool[key_idx] or "?"
      cat_keys[cat.id] = key
      local line = string.format("  [%s]  %-28s %s", key, cat.name, cat.description)
      table.insert(lines, line)
      local li = #lines - 1
      highlights[#highlights + 1] = { li, 2, 5, "SplitTyperMenuKey" }
      highlights[#highlights + 1] = { li, 34, #line, "SplitTyperMenuDesc" }
    end

    table.insert(lines, "")
  end

  local bottom_sep = string.rep("\u{2500}", 50)
  table.insert(lines, bottom_sep)
  highlights[#highlights + 1] = { #lines - 1, 0, #bottom_sep, "SplitTyperSep" }
  table.insert(lines, "")
  table.insert(lines, "  [q] Quit")
  table.insert(lines, "")
  table.insert(lines, "  Press a key to select a category")

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  -- Apply highlights
  if state.ns then
    for _, h in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  -- Set up menu keymaps
  clear_keymaps()

  -- Special keys
  map("c", function()
    M.show_course()
  end)
  map("s", function()
    M.show_dashboard()
  end)
  map("t", function()
    if errs.has_enough_data() then
      M.start_targeted_exercise()
    end
  end)

  for _, cat in ipairs(cats) do
    local key = cat_keys[cat.id]
    if key then
      map(key, function()
        state.mode = "freeplay"
        M.start_exercise(cat.id)
      end)
    end
  end

  map("q", function()
    M.cleanup()
  end)
  map("<Esc>", function()
    M.cleanup()
  end)
  map("<C-c>", function()
    M.cleanup()
  end)
end

-- Start a typing exercise
function M.start_exercise(category_id, exercise_idx)
  state.screen = "exercise"
  state.category_id = category_id

  local text
  if exercise_idx then
    text = exercises.get_exercise(category_id, exercise_idx)
    state.exercise_idx = exercise_idx
  else
    text, state.exercise_idx = exercises.get_random_exercise(category_id)
  end

  if not text then
    vim.notify("No exercise found", vim.log.levels.ERROR)
    return
  end

  -- Check if this category disables backspace
  local cat = exercises.get_category(category_id)
  state.no_backspace = cat and cat.no_backspace or false

  -- Reset session state
  state.target = text
  state.char_map = build_char_map(text)
  state.input = {}
  state.pos = 0
  state.error_count = 0
  state.keystroke_count = 0
  state.start_time = nil
  state.end_time = nil
  state.finished = false
  state.streak = 0
  state.best_streak = 0
  state.error_log = {}
  state.header_extmark = nil

  ensure_window()
  clear_buffer()

  -- Set target text in buffer
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  -- Set up typing keymaps
  setup_typing_keymaps()

  -- Initial display: all text dimmed, first char highlighted as cursor
  update_exercise_display()
end

-- Show results screen
function M.show_results()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  state.screen = "results"
  ensure_window()
  clear_buffer()

  local stats = get_stats()

  -- Determine rating
  local rating, rating_hl
  if stats.score >= 800 then
    rating, rating_hl = "MASTER", "SplitTyperGood"
  elseif stats.score >= 600 then
    rating, rating_hl = "Excellent", "SplitTyperGood"
  elseif stats.score >= 400 then
    rating, rating_hl = "Great", "SplitTyperGood"
  elseif stats.score >= 200 then
    rating, rating_hl = "Good", "SplitTyperOk"
  elseif stats.score >= 100 then
    rating, rating_hl = "Decent", "SplitTyperOk"
  elseif stats.score >= 50 then
    rating, rating_hl = "Getting there", "SplitTyperOk"
  else
    rating, rating_hl = "Keep practicing!", "SplitTyperBad"
  end

  local lines = {}
  local highlights = {}

  local function add(text)
    lines[#lines + 1] = text or ""
  end
  local function hl(col_start, col_end, group)
    highlights[#highlights + 1] = { #lines - 1, col_start, col_end, group }
  end

  add("")
  add("       EXERCISE COMPLETE")
  hl(0, #lines[#lines], "SplitTyperTitle")
  add("")
  local sep = string.rep("\u{2500}", 44)
  add(sep)
  hl(0, #sep, "SplitTyperSep")
  add("")

  local wpm_hl = stats.wpm >= 60 and "SplitTyperGood" or (stats.wpm >= 30 and "SplitTyperOk" or "SplitTyperBad")
  local acc_hl = stats.accuracy >= 95 and "SplitTyperGood"
    or (stats.accuracy >= 80 and "SplitTyperOk" or "SplitTyperBad")

  add(string.format("    WPM:         %d", stats.wpm))
  hl(17, #lines[#lines], wpm_hl)
  add(string.format("    Accuracy:    %.1f%%", stats.accuracy))
  hl(17, #lines[#lines], acc_hl)
  add(string.format("    Errors:      %d", stats.errors))
  hl(17, #lines[#lines], stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood")
  add(string.format("    Best streak: %d", stats.best_streak))
  hl(17, #lines[#lines], stats.best_streak >= stats.total_chars and "SplitTyperGood"
    or (stats.best_streak >= 20 and "SplitTyperOk" or "SplitTyperStats"))
  add(string.format("    Time:        %s", format_time(stats.time)))
  add(string.format("    Characters:  %d", stats.total_chars))
  add("")
  add(string.format("    Score:       %d", stats.score))
  hl(17, #lines[#lines], "SplitTyperScore")
  add(string.format("    Rating:      %s", rating))
  hl(17, #lines[#lines], rating_hl)

  -- Error analysis section
  if #state.error_log > 0 then
    add("")
    add(string.rep("\u{2500}", 44))
    hl(0, #lines[#lines], "SplitTyperSep")
    add("")
    add("    Problem keys this session:")
    hl(0, #lines[#lines], "SplitTyperSep")

    local err_lines, err_hls = errs.format_session_errors(state.error_log)
    local base = #lines
    for _, el in ipairs(err_lines) do
      add(el)
    end
    for _, eh in ipairs(err_hls) do
      highlights[#highlights + 1] = { base + eh[1], eh[2], eh[3], eh[4] }
    end
  end

  add("")
  add(string.rep("\u{2500}", 44))
  hl(0, #lines[#lines], "SplitTyperSep")
  add("")
  add("    [n] Next exercise")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [r] Retry same exercise")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [m] Back to menu")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [s] Stats dashboard")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [q] Quit")
  hl(4, 7, "SplitTyperMenuKey")
  add("")

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  -- Apply highlights
  if state.ns then
    for _, h in ipairs(highlights) do
      pcall(vim.api.nvim_buf_set_extmark, state.buf, state.ns, h[1], h[2], {
        end_col = h[3], hl_group = h[4],
      })
    end
  end

  -- Clear typing keymaps and set results keymaps
  clear_keymaps()

  -- Results screen keymaps
  map("n", function()
    M.start_exercise(state.category_id)
  end)
  map("r", function()
    M.start_exercise(state.category_id, state.exercise_idx)
  end)
  map("m", function()
    M.show_menu()
  end)
  map("s", function()
    M.show_dashboard()
  end)
  map("q", function()
    M.cleanup()
  end)
  map("<Esc>", function()
    M.show_menu()
  end)
  map("<C-c>", function()
    M.cleanup()
  end)
end

-- Stats persistence
local stats_dir = vim.fn.stdpath("data") .. "/split-typer"
local stats_file = stats_dir .. "/history.json"

function save_stats()
  local stats = get_stats()
  if stats.wpm == 0 and stats.typed_chars == 0 then
    return
  end

  -- Record error analysis data
  if state.char_map and #state.error_log > 0 then
    pcall(errs.record_session, state.error_log, state.char_map)
  elseif state.char_map then
    -- Even with no errors, record char totals for accurate rates
    pcall(errs.record_session, {}, state.char_map)
  end

  vim.fn.mkdir(stats_dir, "p")

  local history = {}
  local f = io.open(stats_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
      local ok, data = pcall(vim.json.decode, content)
      if ok and type(data) == "table" then
        history = data
      end
    end
  end

  table.insert(history, {
    date = os.date("%Y-%m-%d %H:%M:%S"),
    category = state.category_id,
    wpm = stats.wpm,
    accuracy = stats.accuracy,
    score = stats.score,
    errors = stats.errors,
    time = math.floor(stats.time),
    chars = stats.total_chars,
  })

  -- Keep last 500 entries
  if #history > 500 then
    local new = {}
    for i = #history - 499, #history do
      new[#new + 1] = history[i]
    end
    history = new
  end

  f = io.open(stats_file, "w")
  if f then
    f:write(vim.json.encode(history))
    f:close()
  end
end

-- Open the plugin
-- Show the stats dashboard
function M.show_dashboard()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  state.screen = "dashboard"
  ensure_window()
  clear_buffer()
  clear_keymaps()

  local dashboard = require("split-typer.dashboard")
  dashboard.render(state.buf, state.ns, state.win, {
    on_back = function()
      M.show_menu()
    end,
    on_quit = function()
      M.cleanup()
    end,
    on_reset_errors = function()
      errs.reset()
      M.show_dashboard()
    end,
  })
end

-- Start a targeted weak-key exercise
function M.start_targeted_exercise()
  state.mode = "freeplay"
  state.screen = "exercise"

  local text, desc = errs.generate_targeted_exercise({ min_words = 12, max_words = 20 })

  state.target = text
  state.char_map = build_char_map(text)
  state.category_id = "targeted_practice"
  state.exercise_idx = nil
  state.no_backspace = false
  state.input = {}
  state.pos = 0
  state.error_count = 0
  state.keystroke_count = 0
  state.start_time = nil
  state.end_time = nil
  state.finished = false
  state.streak = 0
  state.best_streak = 0
  state.error_log = {}
  state.header_extmark = nil

  ensure_window()
  clear_buffer()

  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  setup_typing_keymaps()
  update_exercise_display()
end

function M.open(category)
  setup_highlights()
  math.randomseed(os.time())

  if category and #category > 0 then
    if category == "course" then
      M.show_course()
      return
    end
    if category == "dashboard" then
      M.show_dashboard()
      return
    end
    local cat = exercises.get_category(category)
    if cat then
      ensure_window()
      state.mode = "freeplay"
      M.start_exercise(category)
      return
    end
  end

  M.show_menu()
end

return M
