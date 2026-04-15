local combo = require("split-typer.ui.combo")
local course = require("split-typer.course")
local errs = require("split-typer.errors")
local exercises = require("split-typer.exercises")
local screens = require("split-typer.ui.screens")
local state_mod = require("split-typer.ui.state")
local storage = require("split-typer.storage")
local typing = require("split-typer.ui.typing")
local window = require("split-typer.ui.window")

local M = {}
local random_seeded = false
local stats_file = storage.data_path("history.json")
local state = state_mod.state

local ctx = {
  combo = combo,
  course = course,
  errs = errs,
  exercises = exercises,
  save_combo_stats = nil,
  save_stats = nil,
  state = state,
  state_mod = state_mod,
  window = window,
  actions = {},
}

function M.cleanup()
  window.cleanup(state, state_mod.stop_timer)
end

local function set_buffer_text(text)
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function append_history(entry)
  storage.append_capped(stats_file, entry, 500)
end

local function save_stats()
  local stats = state_mod.get_stats(state)
  if stats.wpm == 0 and stats.typed_chars == 0 then
    return
  end

  if state.char_map and #state.error_log > 0 then
    pcall(errs.record_session, state.error_log, state.char_map)
  elseif state.char_map then
    pcall(errs.record_session, {}, state.char_map)
  end

  append_history({
    date = os.date("%Y-%m-%d %H:%M:%S"),
    category = state.category_id,
    wpm = stats.wpm,
    accuracy = stats.accuracy,
    score = stats.score,
    errors = stats.errors,
    time = math.floor(stats.time),
    chars = stats.total_chars,
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

ctx.save_stats = save_stats
ctx.save_combo_stats = save_combo_stats

function M.show_course()
  screens.show_course(ctx)
end

function M.start_course_exercise(level_id)
  if not course.is_unlocked(level_id) then
    return
  end

  state.mode = "course"
  state.course_level = level_id
  state.screen = "exercise"

  local text = course.generate_exercise(level_id)
  state_mod.reset_typing_session(state, text, {
    category_id = "course_" .. level_id,
    exercise_idx = nil,
    no_backspace = false,
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

function M.show_menu()
  screens.show_menu(ctx)
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

  local cat = exercises.get_category(category_id)
  state_mod.reset_typing_session(state, text, {
    category_id = category_id,
    exercise_idx = state.exercise_idx,
    no_backspace = cat and cat.no_backspace or false,
  })

  window.ensure_window(state, M.cleanup)
  window.clear_buffer(state)
  set_buffer_text(text)
  typing.setup_keymaps(ctx)
  typing.update_display(ctx)
end

function M.show_results()
  screens.show_results(ctx)
end

function M.show_dashboard()
  screens.show_dashboard(ctx)
end

function M.start_targeted_exercise()
  state.mode = "freeplay"
  state.screen = "exercise"

  local text = errs.generate_targeted_exercise({ min_words = 12, max_words = 20 })
  state_mod.reset_typing_session(state, text, {
    category_id = "targeted_practice",
    exercise_idx = nil,
    no_backspace = false,
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
  show_dashboard = function()
    M.show_dashboard()
  end,
  show_menu = function()
    M.show_menu()
  end,
  show_results = function()
    M.show_results()
  end,
  start_combo_exercise = function(category_id)
    M.start_combo_exercise(category_id)
  end,
  start_course_exercise = function(level_id)
    M.start_course_exercise(level_id)
  end,
  start_exercise = function(category_id, exercise_idx)
    M.start_exercise(category_id, exercise_idx)
  end,
  start_targeted_exercise = function()
    M.start_targeted_exercise()
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

    if exercises.get_combo_category(category) then
      window.ensure_window(state, M.cleanup)
      M.start_combo_exercise(category)
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
