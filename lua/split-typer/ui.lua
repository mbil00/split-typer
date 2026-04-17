local combo = require("split-typer.ui.combo")
local course = require("split-typer.course")
local errs = require("split-typer.errors")
local exercises = require("split-typer.exercises")
local reaction = require("split-typer.ui.reaction")
local screens = require("split-typer.ui.screens")
local state_mod = require("split-typer.ui.state")
local storage = require("split-typer.storage")
local typing = require("split-typer.ui.typing")
local window = require("split-typer.ui.window")

local M = {}
local random_seeded = false
local state = state_mod.state

local ctx = {
  combo = combo,
  course = course,
  errs = errs,
  exercises = exercises,
  save_combo_stats = nil,
  reaction = reaction,
  save_reaction_stats = nil,
  save_stats = nil,
  state = state,
  state_mod = state_mod,
  window = window,
  actions = {},
}

function M.cleanup()
  window.cleanup(state, state_mod.stop_timer)
end

local function get_stats_file()
  return storage.layout_data_path("history")
end

local function set_buffer_text(text)
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function append_history(entry)
  local _, ok = storage.append_capped(get_stats_file(), entry, 500)
  if ok == false then
    vim.schedule(function()
      vim.notify("split-typer: failed to save session history", vim.log.levels.WARN)
    end)
  end
end

local function get_typed_char_map()
  if not state.char_map then
    return nil
  end
  if not state.timed_mode or state.pos >= #state.char_map then
    return state.char_map
  end

  local typed = {}
  for i = 1, state.pos do
    typed[i] = state.char_map[i]
  end
  return typed
end

local function generate_timed_chunk()
  local text = errs.generate_targeted_exercise({
    allowed_chars = "abcdefghijklmnopqrstuvwxyz",
    seed_chars = errs.get_adaptive_focus_chars({
      allowed_chars = "abcdefghijklmnopqrstuvwxyz",
      limit = 5,
      min_total = 12,
    }),
    min_focus_occurrences = 16,
    min_words = 22,
    max_words = 32,
  })
  return text
end

local function build_timed_postmortem(typed_char_map)
  if not state.timed_mode then
    return nil
  end

  local session_chars = errs.get_session_worst_chars(state.error_log, 5)
  local session_bigrams = errs.get_session_worst_bigrams(state.error_log, typed_char_map, 5, state.pos)
  local decay = errs.get_session_decay(state.key_events)

  local chars_out = {}
  for _, item in ipairs(session_chars) do
    chars_out[#chars_out + 1] = {
      char = item.char,
      count = item.count,
    }
  end

  local bigrams_out = {}
  for _, item in ipairs(session_bigrams) do
    bigrams_out[#bigrams_out + 1] = {
      bigram = item.bigram,
      error_rate = item.error_rate,
      errors = item.errors,
      total = item.total,
    }
  end

  local decay_out = nil
  if decay then
    decay_out = {
      first = {
        wpm = math.floor(decay.first.wpm),
        accuracy = math.floor(decay.first.accuracy * 10) / 10,
        efficiency = math.floor(decay.first.efficiency * 10) / 10,
      },
      second = {
        wpm = math.floor(decay.second.wpm),
        accuracy = math.floor(decay.second.accuracy * 10) / 10,
        efficiency = math.floor(decay.second.efficiency * 10) / 10,
      },
      wpm_delta = math.floor(decay.wpm_delta),
      accuracy_delta = math.floor(decay.accuracy_delta * 10) / 10,
      efficiency_delta = math.floor(decay.efficiency_delta * 10) / 10,
    }
  end

  return {
    worst_chars = chars_out,
    worst_bigrams = bigrams_out,
    decay = decay_out,
  }
end

local function save_stats()
  local stats = state_mod.get_stats(state)
  if stats.wpm == 0 and stats.typed_chars == 0 then
    return
  end

  local typed_char_map = get_typed_char_map()
  if typed_char_map and #state.error_log > 0 then
    pcall(errs.record_session, state.error_log, typed_char_map)
  elseif typed_char_map then
    pcall(errs.record_session, {}, typed_char_map)
  end

  local timed_postmortem = build_timed_postmortem(typed_char_map)

  append_history({
    date = os.date("%Y-%m-%d %H:%M:%S"),
    category = state.category_id,
    wpm = stats.wpm,
    gross_wpm = stats.gross_wpm,
    accuracy = stats.accuracy,
    efficiency = stats.efficiency,
    score = stats.score,
    errors = stats.errors,
    backspaces = stats.backspaces,
    time = math.floor(stats.time),
    chars = stats.total_chars,
    timed = state.timed_mode or nil,
    timed_postmortem = timed_postmortem,
  })
end

local function save_combo_stats()
  local stats = state_mod.get_combo_stats(state)
  if stats.completed == 0 then
    return
  end

  append_history({
    date = os.date("%Y-%m-%d %H:%M:%S"),
    category = state.category_id,
    wpm = stats.cpm,
    accuracy = stats.accuracy,
    score = stats.score,
    errors = stats.errors,
    time = math.floor(stats.time),
    chars = stats.completed,
  })
end

local function save_reaction_stats()
  local stats = state_mod.get_reaction_stats(state)
  if stats.completed == 0 then
    return
  end

  append_history({
    date = os.date("%Y-%m-%d %H:%M:%S"),
    category = state.category_id,
    wpm = stats.cpm,
    accuracy = stats.accuracy,
    score = stats.score,
    errors = stats.errors,
    time = math.floor(stats.time),
    chars = stats.completed,
  })
end

ctx.save_stats = save_stats
ctx.save_combo_stats = save_combo_stats
ctx.save_reaction_stats = save_reaction_stats

function M.show_course()
  screens.show_course(ctx)
end

function M.start_course_exercise(level_id, stage_id)
  if not course.is_unlocked(level_id) then
    return
  end

  stage_id = stage_id or course.pick_next_stage(level_id)

  state.mode = "course"
  state.course_level = level_id
  state.course_stage = stage_id
  state.screen = "exercise"

  local text = course.generate_exercise(level_id, stage_id)
  state_mod.reset_typing_session(state, text, {
    category_id = "course_" .. level_id .. "_" .. stage_id,
    exercise_idx = nil,
    no_backspace = true,
  })

  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  set_buffer_text(text)
  typing.setup_keymaps(ctx)
  typing.update_display(ctx)
end

function M.show_course_results()
  screens.show_course_results(ctx)
end

function M.show_combo_menu()
  screens.show_combo_menu(ctx)
end

function M.start_combo_exercise(category_id)
  state.screen = "combo_exercise"
  state.category_id = category_id
  state.combo_mode = true

  local combos = exercises.generate_combo_exercise(category_id)
  if not combos then
    vim.notify("No combo exercise found", vim.log.levels.ERROR)
    return
  end

  state_mod.reset_combo_session(state, category_id, combos)
  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  combo.setup_keymaps(ctx)
  combo.update_display(ctx)
end

function M.show_combo_results()
  screens.show_combo_results(ctx)
end

function M.show_reaction_menu()
  screens.show_reaction_menu(ctx)
end

function M.start_reaction_exercise(category_id)
  state.screen = "reaction_exercise"
  state.category_id = category_id
  state.reaction_mode = true

  local prompts = exercises.generate_reaction_exercise(category_id)
  if not prompts then
    vim.notify("No reaction exercise found", vim.log.levels.ERROR)
    return
  end

  state_mod.reset_reaction_session(state, category_id, prompts)
  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  reaction.setup_keymaps(ctx)
  reaction.update_display(ctx)
end

function M.show_reaction_results()
  screens.show_reaction_results(ctx)
end

function M.show_transition_menu()
  screens.show_transition_menu(ctx)
end

function M.show_menu()
  screens.show_menu(ctx)
end

function M.show_group(group_id)
  screens.show_group(ctx, group_id)
end

function M.cycle_strictness()
  state_mod.cycle_strictness(state)
  if state.screen == "menu" then
    M.show_menu()
  elseif state.screen == "group" then
    M.show_group(state.group_id)
  end
end

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

  local opts = state_mod.apply_strictness({
    category_id = category_id,
    exercise_idx = state.exercise_idx,
  }, state.strictness)
  state_mod.reset_typing_session(state, text, opts)

  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  set_buffer_text(text)
  typing.setup_keymaps(ctx)
  typing.update_display(ctx)
end

function M.restart_current_text()
  if not state.target or #state.target == 0 then
    return
  end

  local opts = state_mod.apply_strictness({
    category_id = state.category_id,
    exercise_idx = state.exercise_idx,
  }, state.strictness)
  state_mod.reset_typing_session(state, state.target, opts)

  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  set_buffer_text(state.target)
  typing.setup_keymaps(ctx)
  typing.update_display(ctx)
end

function M.show_results()
  screens.show_results(ctx)
end

function M.show_timed_menu()
  screens.show_timed_menu(ctx)
end

function M.show_dashboard()
  screens.show_dashboard(ctx)
end

function M.start_targeted_exercise()
  state.mode = "freeplay"
  state.screen = "exercise"

  local text, desc = errs.generate_targeted_exercise({ min_words = 16, max_words = 26, min_focus_occurrences = 14 })
  state_mod.reset_typing_session(state, text, {
    category_id = "targeted_practice",
    exercise_idx = nil,
    no_backspace = false,
    generated_desc = desc,
  })

  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  set_buffer_text(text)
  typing.setup_keymaps(ctx)
  typing.update_display(ctx)
end

function M.start_transition_exercise(class_id)
  state.mode = "freeplay"
  state.screen = "exercise"

  local text, desc = errs.generate_transition_exercise({
    class_id = class_id,
    min_words = 16,
    max_words = 24,
    min_transition_hits = 14,
  })
  state_mod.reset_typing_session(state, text, {
    category_id = "transition_practice",
    exercise_idx = nil,
    no_backspace = false,
    generated_desc = desc,
    transition_focus_class = class_id,
  })

  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  set_buffer_text(text)
  typing.setup_keymaps(ctx)
  typing.update_display(ctx)
end

function M.start_timed_session(minutes)
  state.mode = "timed"
  state.screen = "exercise"

  local first = generate_timed_chunk()
  local second = generate_timed_chunk()
  local text = first .. "\n" .. second
  state_mod.reset_typing_session(state, text, {
    category_id = "timed_" .. tostring(minutes) .. "m",
    exercise_idx = nil,
    no_backspace = false,
    timed_mode = true,
    timed_duration = minutes * 60,
    chunk_generator = generate_timed_chunk,
  })

  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  set_buffer_text(text)
  typing.setup_keymaps(ctx)
  typing.update_display(ctx)
end

ctx.actions = {
  cleanup = function()
    M.cleanup()
  end,
  show_course = function()
    M.show_course()
  end,
  show_course_results = function()
    M.show_course_results()
  end,
  show_combo_menu = function()
    M.show_combo_menu()
  end,
  show_combo_results = function()
    M.show_combo_results()
  end,
  show_reaction_menu = function()
    M.show_reaction_menu()
  end,
  show_reaction_results = function()
    M.show_reaction_results()
  end,
  show_transition_menu = function()
    M.show_transition_menu()
  end,
  show_dashboard = function()
    M.show_dashboard()
  end,
  show_timed_menu = function()
    M.show_timed_menu()
  end,
  show_menu = function()
    M.show_menu()
  end,
  show_group = function(group_id)
    M.show_group(group_id)
  end,
  cycle_strictness = function()
    M.cycle_strictness()
  end,
  show_results = function()
    M.show_results()
  end,
  start_combo_exercise = function(category_id)
    M.start_combo_exercise(category_id)
  end,
  start_reaction_exercise = function(category_id)
    M.start_reaction_exercise(category_id)
  end,
  start_course_exercise = function(level_id, stage_id)
    M.start_course_exercise(level_id, stage_id)
  end,
  start_exercise = function(category_id, exercise_idx)
    M.start_exercise(category_id, exercise_idx)
  end,
  restart_current_text = function()
    M.restart_current_text()
  end,
  start_targeted_exercise = function()
    M.start_targeted_exercise()
  end,
  start_transition_exercise = function(class_id)
    M.start_transition_exercise(class_id)
  end,
  start_timed_session = function(minutes)
    M.start_timed_session(minutes)
  end,
}

function M.open(category)
  window.setup_highlights()
  if not random_seeded then
    math.randomseed(vim.uv.hrtime())
    random_seeded = true
  end

  if category and #category > 0 then
    if category == "course" then
      M.show_course()
      return
    end
    if category == "dashboard" then
      M.show_dashboard()
      return
    end
    if category == "combos" then
      M.show_combo_menu()
      return
    end
    if category == "reaction" then
      M.show_reaction_menu()
      return
    end
    if category == "timed" then
      M.show_timed_menu()
      return
    end
    if category == "transitions" then
      window.ensure_window(state, M.cleanup)
      M.show_transition_menu()
      return
    end
    if category == "weak_keys" then
      window.ensure_window(state, M.cleanup)
      M.start_targeted_exercise()
      return
    end

    if exercises.get_group(category) then
      window.ensure_window(state, M.cleanup)
      M.show_group(category)
      return
    end

    if exercises.get_combo_category(category) then
      window.ensure_window(state, M.cleanup)
      M.start_combo_exercise(category)
      return
    end

    if exercises.get_reaction_category(category) then
      window.ensure_window(state, M.cleanup)
      M.start_reaction_exercise(category)
      return
    end

    if exercises.get_category(category) then
      window.ensure_window(state, M.cleanup)
      state.mode = "freeplay"
      M.start_exercise(category)
      return
    end
  end

  M.show_menu()
end

return M
