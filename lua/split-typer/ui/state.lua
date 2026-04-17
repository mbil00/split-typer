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
  course_stage = nil,
  target = nil,
  generated_desc = nil,
  transition_focus_class = nil,
  char_map = nil,
  input = {},
  pos = 0,
  correct_count = 0,
  error_count = 0,
  keystroke_count = 0,
  backspace_count = 0,
  start_time = nil,
  end_time = nil,
  finished = false,
  no_backspace = false,
  error_limit = nil,
  repeat_until_clean = false,
  fail_reason = nil,
  failed_early = false,
  streak = 0,
  best_streak = 0,
  error_log = {},
  key_events = {},
  header_extmark = nil,
  timed_mode = false,
  timed_duration = 0,
  timed_deadline = nil,
  chunk_generator = nil,
  combo_mode = false,
  combos = nil,
  combo_idx = 0,
  combo_results = {},
  combo_feedback = nil,
  combo_waiting = false,
  reaction_mode = false,
  reaction_prompts = nil,
  reaction_idx = 0,
  reaction_results = {},
  reaction_feedback = nil,
  reaction_waiting = false,
  reaction_prompt_started_at = nil,
  results_unlock_at = nil,
  results_lock_extmark = nil,
  mapped_keys = {},
  strictness = "normal",
}

-- Ordered list of strictness modes. "." cycles through them.
M.strictness_modes = { "normal", "precision", "accuracy" }

local STRICTNESS_LABEL = {
  normal = "Normal",
  precision = "Precision",
  accuracy = "Accuracy",
}

local STRICTNESS_HINT = {
  normal = "backspace allowed, no error cap",
  precision = "no backspace",
  accuracy = "no backspace, first-error fail, repeat until clean",
}

function M.cycle_strictness(state)
  local current = state.strictness or "normal"
  for i, mode in ipairs(M.strictness_modes) do
    if mode == current then
      state.strictness = M.strictness_modes[i % #M.strictness_modes + 1]
      return state.strictness
    end
  end
  state.strictness = "normal"
  return state.strictness
end

function M.strictness_label(mode)
  return STRICTNESS_LABEL[mode or "normal"] or "Normal"
end

function M.strictness_hint(mode)
  return STRICTNESS_HINT[mode or "normal"] or ""
end

--- Fold the active strictness mode into an opts table destined for
--- reset_typing_session. Caller is responsible for deciding whether the
--- mode applies (only freeplay uses it; course/timed/weak/transition keep
--- their own rules).
function M.apply_strictness(opts, mode)
  opts = opts or {}
  mode = mode or "normal"
  if mode == "precision" then
    opts.no_backspace = true
  elseif mode == "accuracy" then
    opts.no_backspace = true
    opts.error_limit = 0
    opts.repeat_until_clean = true
  end
  return opts
end

local function reset_session_state(state)
  state.target = nil
  state.generated_desc = nil
  state.transition_focus_class = nil
  state.char_map = nil
  state.input = {}
  state.pos = 0
  state.correct_count = 0
  state.error_count = 0
  state.keystroke_count = 0
  state.backspace_count = 0
  state.start_time = nil
  state.end_time = nil
  state.finished = false
  state.no_backspace = false
  state.error_limit = nil
  state.repeat_until_clean = false
  state.fail_reason = nil
  state.failed_early = false
  state.streak = 0
  state.best_streak = 0
  state.error_log = {}
  state.key_events = {}
  state.header_extmark = nil
  state.timed_mode = false
  state.timed_duration = 0
  state.timed_deadline = nil
  state.chunk_generator = nil
  state.combo_mode = false
  state.combos = nil
  state.combo_idx = 0
  state.combo_results = {}
  state.combo_feedback = nil
  state.combo_waiting = false
  state.reaction_mode = false
  state.reaction_prompts = nil
  state.reaction_idx = 0
  state.reaction_results = {}
  state.reaction_feedback = nil
  state.reaction_waiting = false
  state.reaction_prompt_started_at = nil
  state.results_unlock_at = nil
  state.results_lock_extmark = nil
end

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
  reset_session_state(state)
  state.target = text
  state.generated_desc = opts.generated_desc
  state.transition_focus_class = opts.transition_focus_class
  state.char_map = M.build_char_map(text)
  state.category_id = opts.category_id
  state.exercise_idx = opts.exercise_idx
  state.no_backspace = opts.no_backspace or false
  state.error_limit = opts.error_limit
  state.repeat_until_clean = opts.repeat_until_clean or false
  state.timed_mode = opts.timed_mode or false
  state.timed_duration = opts.timed_duration or 0
  state.chunk_generator = opts.chunk_generator
end

function M.reset_combo_session(state, category_id, combos)
  reset_session_state(state)
  state.category_id = category_id
  state.combo_mode = true
  state.combos = combos
  state.combo_idx = 1
end

function M.reset_reaction_session(state, category_id, prompts)
  reset_session_state(state)
  state.category_id = category_id
  state.reaction_mode = true
  state.reaction_prompts = prompts
  state.reaction_idx = 1
  state.reaction_prompt_started_at = vim.uv.hrtime()
  state.no_backspace = true
end

function M.get_stats(state)
  if not state.start_time then
    return {
      wpm = 0,
      gross_wpm = 0,
      accuracy = 100,
      efficiency = 100,
      time = 0,
      score = 0,
      errors = 0,
      backspaces = 0,
      remaining_time = 0,
      timed_mode = state.timed_mode,
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
  local accuracy_base = correct + state.error_count
  local accuracy = accuracy_base > 0 and (correct / accuracy_base * 100) or 100
  local efficiency = state.keystroke_count > 0 and (correct / state.keystroke_count * 100) or 100
  local gross_wpm = elapsed > 0 and ((state.pos / 5) / (elapsed / 60)) or 0
  local wpm = elapsed > 0 and ((correct / 5) / (elapsed / 60)) or 0
  local score = math.floor(wpm * (accuracy / 100) * (efficiency / 100))
  local remaining_time = 0
  if state.timed_mode and state.timed_deadline then
    remaining_time = math.max(0, (state.timed_deadline - end_t) / 1e9)
  end

  return {
    wpm = math.floor(wpm),
    gross_wpm = math.floor(gross_wpm),
    accuracy = math.floor(accuracy * 10) / 10,
    efficiency = math.floor(efficiency * 10) / 10,
    time = elapsed,
    score = score,
    errors = state.error_count,
    correct = correct,
    total_chars = state.timed_mode and state.pos or #state.char_map,
    typed_chars = state.pos,
    keystrokes = state.keystroke_count,
    backspaces = state.backspace_count,
    remaining_time = remaining_time,
    timed_mode = state.timed_mode,
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

function M.get_reaction_stats(state)
  if not state.start_time then
    return {
      cpm = 0,
      accuracy = 100,
      time = 0,
      score = 0,
      errors = 0,
      correct = 0,
      total = state.reaction_prompts and #state.reaction_prompts or 0,
      completed = 0,
      streak = 0,
      best_streak = 0,
      avg_reaction_ms = 0,
      avg_correct_reaction_ms = 0,
      best_reaction_ms = 0,
      keystrokes = 0,
    }
  end

  local end_t = state.end_time or vim.uv.hrtime()
  local elapsed = (end_t - state.start_time) / 1e9

  local completed = 0
  local correct = 0
  local reaction_total = 0
  local correct_reaction_total = 0
  local best_reaction_ms = nil
  for _, result in ipairs(state.reaction_results) do
    completed = completed + 1
    reaction_total = reaction_total + result.reaction_ms
    if result.correct then
      correct = correct + 1
      correct_reaction_total = correct_reaction_total + result.reaction_ms
      if not best_reaction_ms or result.reaction_ms < best_reaction_ms then
        best_reaction_ms = result.reaction_ms
      end
    end
  end

  local accuracy = completed > 0 and (correct / completed * 100) or 100
  local cpm = elapsed > 0 and (completed / (elapsed / 60)) or 0
  local avg_reaction_ms = completed > 0 and (reaction_total / completed) or 0
  local avg_correct_reaction_ms = correct > 0 and (correct_reaction_total / correct) or 0
  local speed_bonus = avg_reaction_ms > 0 and math.min(2, 700 / avg_reaction_ms) or 0
  local score = math.floor(cpm * (accuracy / 100) * speed_bonus)

  return {
    cpm = math.floor(cpm),
    accuracy = math.floor(accuracy * 10) / 10,
    time = elapsed,
    score = score,
    errors = state.error_count,
    correct = correct,
    total = state.reaction_prompts and #state.reaction_prompts or completed,
    completed = completed,
    keystrokes = state.keystroke_count,
    streak = state.streak,
    best_streak = state.best_streak,
    avg_reaction_ms = math.floor(avg_reaction_ms),
    avg_correct_reaction_ms = math.floor(avg_correct_reaction_ms),
    best_reaction_ms = best_reaction_ms and math.floor(best_reaction_ms) or 0,
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
