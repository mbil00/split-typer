local M = {}

M.state = {
  buf = nil,
  win = nil,
  ns = nil,
  timer = nil,
  screen = nil,
  category_id = nil,
  exercise_idx = nil,
  mode = "freeplay",
  course_level = nil,
  target = nil,
  char_map = nil,
  input = {},
  pos = 0,
  correct_count = 0,
  error_count = 0,
  keystroke_count = 0,
  start_time = nil,
  end_time = nil,
  finished = false,
  no_backspace = false,
  streak = 0,
  best_streak = 0,
  error_log = {},
  header_extmark = nil,
  combo_mode = false,
  combos = nil,
  combo_idx = 0,
  combo_results = {},
  combo_feedback = nil,
  combo_waiting = false,
  mapped_keys = {},
}

function M.build_char_map(text)
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

function M.reset_typing_session(state, text, opts)
  opts = opts or {}
  state.target = text
  state.char_map = M.build_char_map(text)
  state.category_id = opts.category_id
  state.exercise_idx = opts.exercise_idx
  state.no_backspace = opts.no_backspace or false
  state.combo_mode = false
  state.combos = nil
  state.combo_idx = 0
  state.combo_results = {}
  state.combo_feedback = nil
  state.combo_waiting = false
  state.input = {}
  state.pos = 0
  state.correct_count = 0
  state.error_count = 0
  state.keystroke_count = 0
  state.start_time = nil
  state.end_time = nil
  state.finished = false
  state.streak = 0
  state.best_streak = 0
  state.error_log = {}
  state.header_extmark = nil
end

function M.reset_combo_session(state, category_id, combos)
  state.category_id = category_id
  state.combo_mode = true
  state.combos = combos
  state.combo_idx = 1
  state.combo_results = {}
  state.combo_feedback = nil
  state.combo_waiting = false
  state.target = nil
  state.char_map = nil
  state.input = {}
  state.pos = 0
  state.correct_count = 0
  state.error_count = 0
  state.keystroke_count = 0
  state.start_time = nil
  state.end_time = nil
  state.finished = false
  state.streak = 0
  state.best_streak = 0
  state.error_log = {}
  state.header_extmark = nil
end

function M.get_stats(state)
  if not state.start_time then
    return {
      wpm = 0,
      accuracy = 100,
      time = 0,
      score = 0,
      errors = 0,
      streak = 0,
      best_streak = 0,
      total_chars = 0,
      typed_chars = 0,
      keystrokes = 0,
    }
  end

  local end_t = state.end_time or vim.uv.hrtime()
  local elapsed = (end_t - state.start_time) / 1e9
  local correct = state.correct_count
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

function M.get_combo_stats(state)
  if not state.start_time then
    return {
      cpm = 0,
      accuracy = 100,
      time = 0,
      score = 0,
      errors = 0,
      correct = 0,
      total = 0,
      completed = 0,
      streak = 0,
      best_streak = 0,
      keystrokes = 0,
    }
  end

  local end_t = state.end_time or vim.uv.hrtime()
  local elapsed = (end_t - state.start_time) / 1e9

  local completed = 0
  local correct = 0
  for _, result in pairs(state.combo_results) do
    completed = completed + 1
    if result.correct then
      correct = correct + 1
    end
  end

  local accuracy = completed > 0 and (correct / completed * 100) or 100
  local cpm = elapsed > 0 and (completed / (elapsed / 60)) or 0
  local score = math.floor(cpm * (accuracy / 100) * (accuracy / 100))

  return {
    cpm = math.floor(cpm),
    accuracy = math.floor(accuracy * 10) / 10,
    time = elapsed,
    score = score,
    errors = state.error_count,
    correct = correct,
    total = #state.combos,
    completed = completed,
    keystrokes = state.keystroke_count,
    streak = state.streak,
    best_streak = state.best_streak,
  }
end

function M.format_time(seconds)
  local m = math.floor(seconds / 60)
  local s = math.floor(seconds % 60)
  return string.format("%d:%02d", m, s)
end

function M.stop_timer(state)
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

return M
