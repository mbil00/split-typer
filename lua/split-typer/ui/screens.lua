local M = {}
local RESULTS_INPUT_COOLDOWN_MS = 2000

local function build_menu_key_pool(reserved)
  local pool = {}
  for i = 1, 9 do
    pool[#pool + 1] = tostring(i)
  end
  pool[#pool + 1] = "0"
  for ch = string.byte("a"), string.byte("z") do
    local key = string.char(ch)
    if not reserved[key] then
      pool[#pool + 1] = key
    end
  end
  for _, extra in ipairs({ "A", "B", "C", "D", "E" }) do
    pool[#pool + 1] = extra
  end
  return pool
end

local function render_buffer(state, lines, highlights)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  if state.ns then
    for _, h in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end
end

local function get_results_lock_remaining_ms(state)
  if not state.results_unlock_at then
    return 0
  end

  return math.max(0, math.ceil((state.results_unlock_at - vim.uv.hrtime()) / 1e6))
end

local function update_results_lock_hint(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or not state.ns then
    return
  end

  local remaining_ms = get_results_lock_remaining_ms(state)
  if remaining_ms <= 0 then
    state.results_unlock_at = nil
    if state.results_lock_extmark then
      pcall(vim.api.nvim_buf_del_extmark, state.buf, state.ns, state.results_lock_extmark)
      state.results_lock_extmark = nil
    end
    return
  end

  local line_count = vim.api.nvim_buf_line_count(state.buf)
  local message = string.format(
    "  Actions unlock in %.1fs to avoid stray keystrokes after the timer ends.",
    remaining_ms / 1000
  )

  state.results_lock_extmark = vim.api.nvim_buf_set_extmark(state.buf, state.ns, line_count - 1, 0, {
    id = state.results_lock_extmark,
    virt_lines = {
      { { "", "" } },
      { { message, "SplitTyperPending" } },
    },
  })
end

local function start_results_input_lock(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.results_unlock_at = vim.uv.hrtime() + (RESULTS_INPUT_COOLDOWN_MS * 1e6)
  update_results_lock_hint(ctx)

  state.timer = vim.uv.new_timer()
  state.timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      update_results_lock_hint(ctx)
      if get_results_lock_remaining_ms(state) <= 0 then
        ctx.state_mod.stop_timer(state)
      end
    end)
  )
end

local function add_results_input_lock_notice(state, lines, highlights)
  local remaining_ms = get_results_lock_remaining_ms(state)
  if remaining_ms <= 0 then
    return
  end

  lines[#lines + 1] = ""
  local line = "    Actions are briefly locked to avoid stray keystrokes after the timer ends."
  lines[#lines + 1] = line
  highlights[#highlights + 1] = { #lines - 1, 0, #line, "SplitTyperPending" }
end

local function map_results_action(ctx, key, fn)
  ctx.window.map(ctx.state, key, function()
    if get_results_lock_remaining_ms(ctx.state) > 0 then
      return
    end
    fn()
  end)
end

function M.show_course(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "course"
  state.mode = "course"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local levels = ctx.course.levels
  local current = ctx.course.get_current_level()
  local lines = {}
  local highlights = {}

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       TOUCH TYPING COURSE"
  lines[#lines + 1] = "       Structured progression for split keyboard mastery"
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }

  local sep = string.rep("\u{2500}", 82)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""

  -- Stage legend so the two-letter codes in the per-level line are readable.
  local legend_parts = {}
  for _, sd in ipairs(ctx.course.stage_defs) do
    legend_parts[#legend_parts + 1] = sd.short .. "=" .. sd.name
  end
  local legend_line = "  Stages: " .. table.concat(legend_parts, "  ")
  lines[#lines + 1] = legend_line
  highlights[#highlights + 1] = { #lines - 1, 0, #legend_line, "SplitTyperMenuDesc" }
  lines[#lines + 1] = ""

  local level_keys = {}
  for _, level in ipairs(levels) do
    local progress = ctx.course.get_level_progress(level.id)
    local unlocked = ctx.course.is_unlocked(level.id)
    local key
    if level.id < 10 then
      key = tostring(level.id)
    elseif level.id == 10 then
      key = "0"
    elseif level.id == 11 then
      key = "a"
    else
      key = "b"
    end

    -- Build the "SK:2/2 BG:1/2 ..." chunk.
    local stage_chunks = {}
    local passed_count = 0
    for _, sd in ipairs(ctx.course.stage_defs) do
      local sp = progress.stages[sd.id] or { completed = 0, passed = false }
      local reps = 2
      for _, s in ipairs(level.stages) do
        if s.id == sd.id then reps = s.reps_required break end
      end
      local done = math.min(sp.completed or 0, reps)
      stage_chunks[#stage_chunks + 1] = string.format("%s:%d/%d", sd.short, done, reps)
      if sp.passed then passed_count = passed_count + 1 end
    end
    local stage_summary = table.concat(stage_chunks, " ")

    local status, status_hl
    if progress.passed then
      if progress.best_wpm > 0 then
        status = string.format("PASSED  best %d WPM %.0f%%", progress.best_wpm, progress.best_accuracy)
      else
        status = "PASSED"
      end
      status_hl = "SplitTyperGood"
    elseif unlocked then
      status = string.format("%s  (%d/%d stages)", stage_summary, passed_count, #ctx.course.stage_defs)
      status_hl = "SplitTyperOk"
    else
      status = "LOCKED"
      status_hl = "SplitTyperPending"
    end

    local marker = (level.id == current and not progress.passed) and ">" or " "
    local line
    if unlocked then
      line = string.format(" %s[%s]  %-18s [%s]", marker, key, level.name, level.new_chars)
      level_keys[key] = level.id
    else
      line = string.format("  -   %-18s [%s]", level.name, level.new_chars)
    end
    line = line .. string.rep(" ", math.max(0, 44 - #line)) .. status
    lines[#lines + 1] = line

    local line_idx = #lines - 1
    if unlocked then
      highlights[#highlights + 1] = { line_idx, 2, 5, "SplitTyperMenuKey" }
    end
    highlights[#highlights + 1] = { line_idx, #line - #status, #line, status_hl }
    if marker == ">" then
      highlights[#highlights + 1] = { line_idx, 0, 1, "SplitTyperOk" }
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Each level runs 5 stage types; each must be cleared twice to pass."
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = "  Pressing a level key auto-picks a not-yet-passed stage. Strict mode: no backspace."
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = ""
  local sep2 = string.rep("\u{2500}", 82)
  lines[#lines + 1] = sep2
  highlights[#highlights + 1] = { #lines - 1, 0, #sep2, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Press a level number to start     [Esc] Back to menu    [q] Quit    [R] Reset progress"

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  if state.ns then
    for _, h in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  ctx.window.clear_keymaps(state)
  for key, level_id in pairs(level_keys) do
    ctx.window.map(state, key, function()
      ctx.actions.start_course_exercise(level_id)
    end)
  end
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
  ctx.window.map(state, "R", function()
    ctx.course.reset_progress()
    M.show_course(ctx)
  end)
end

function M.show_course_results(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "course_results"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local stats = ctx.state_mod.get_stats(state)
  local level_id = state.course_level
  local stage_id = state.course_stage
  local level = ctx.course.get_level(level_id)
  local stage = ctx.course.get_stage(level_id, stage_id)
  local passed_exercise, stage_cleared, level_complete = ctx.course.record_exercise(
    level_id,
    stage_id,
    stats.wpm,
    stats.accuracy,
    stats.efficiency,
    stats.errors
  )
  local level_prog = ctx.course.get_level_progress(level_id)
  local stage_prog = level_prog.stages[stage_id] or { completed = 0, passed = false, best_wpm = 0, best_accuracy = 0 }

  local lines = { "" }
  local highlights = {}

  if level_complete then
    lines[#lines + 1] = "       LEVEL COMPLETE!"
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif stage_cleared then
    lines[#lines + 1] = string.format("       STAGE CLEARED: %s", stage.name)
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif passed_exercise then
    lines[#lines + 1] = "       EXERCISE PASSED"
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperOk" }
  else
    lines[#lines + 1] = "       NOT YET..."
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperBad" }
  end

  lines[#lines + 1] = string.format("       Level %d: %s  -  %s", level_id, level.name, stage.name)
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperHeader" }

  if not passed_exercise then
    local reasons = {}
    if stats.wpm < stage.req_wpm then
      reasons[#reasons + 1] = string.format("WPM too low (%d < %d)", stats.wpm, stage.req_wpm)
    end
    if stats.accuracy < stage.req_accuracy then
      reasons[#reasons + 1] = string.format("Accuracy too low (%.1f%% < %.0f%%)", stats.accuracy, stage.req_accuracy)
    end
    if stats.efficiency < stage.req_efficiency then
      reasons[#reasons + 1] = string.format("Efficiency too low (%.1f%% < %.0f%%)", stats.efficiency, stage.req_efficiency)
    end
    if stats.errors > stage.req_max_errors then
      reasons[#reasons + 1] = string.format("Too many errors (%d > %d max)", stats.errors, stage.req_max_errors)
    end
    if #reasons > 0 then
      local line = "       " .. table.concat(reasons, " | ")
      lines[#lines + 1] = line
      highlights[#highlights + 1] = { #lines - 1, 0, #line, "SplitTyperBad" }
    end
  end

  lines[#lines + 1] = ""
  local sep = string.rep("\u{2500}", 60)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""

  local wpm_line = string.format("    Net WPM:     %d", stats.wpm)
  local gross_line = string.format("    Gross WPM:   %d", stats.gross_wpm)
  local acc_line = string.format("    Accuracy:    %.1f%%", stats.accuracy)
  local eff_line = string.format("    Efficiency:  %.1f%%", stats.efficiency)
  local err_line = string.format("    Errors:      %d", stats.errors)
  local back_line = string.format("    Backspaces:  %d", stats.backspaces)
  local time_line = string.format("    Time:        %s", ctx.state_mod.format_time(stats.time))
  lines[#lines + 1] = wpm_line
  lines[#lines + 1] = gross_line
  lines[#lines + 1] = acc_line
  lines[#lines + 1] = eff_line
  lines[#lines + 1] = err_line
  lines[#lines + 1] = back_line
  lines[#lines + 1] = time_line

  highlights[#highlights + 1] = { #lines - 6, 17, #wpm_line, stats.wpm >= stage.req_wpm and "SplitTyperGood" or "SplitTyperBad" }
  highlights[#highlights + 1] = { #lines - 4, 17, #acc_line, stats.accuracy >= stage.req_accuracy and "SplitTyperGood" or "SplitTyperBad" }
  highlights[#highlights + 1] = { #lines - 3, 17, #eff_line, stats.efficiency >= stage.req_efficiency and "SplitTyperGood" or "SplitTyperBad" }
  highlights[#highlights + 1] = { #lines - 2, 17, #err_line, stats.errors <= stage.req_max_errors and "SplitTyperGood" or "SplitTyperBad" }

  lines[#lines + 1] = ""
  local req_line = string.format(
    "    Required:    %d WPM, %.0f%% acc, %.0f%% eff, %d max errors",
    stage.req_wpm,
    stage.req_accuracy,
    stage.req_efficiency,
    stage.req_max_errors
  )
  lines[#lines + 1] = req_line
  highlights[#highlights + 1] = { #lines - 1, 17, #req_line, "SplitTyperSep" }

  local stage_line = string.format("    %s:    %d/%d passes", stage.name, math.min(stage_prog.completed, stage.reps_required), stage.reps_required)
  lines[#lines + 1] = stage_line
  highlights[#highlights + 1] = { #lines - 1, 17, #stage_line, stage_prog.passed and "SplitTyperGood" or "SplitTyperOk" }

  -- Level-wide stage summary so the user knows what's left.
  local pending = ctx.course.pending_stages(level_id)
  local pending_names = {}
  for _, sid in ipairs(pending) do
    local s = ctx.course.get_stage(level_id, sid)
    if s then pending_names[#pending_names + 1] = s.name end
  end
  local pending_line
  if #pending_names == 0 then
    pending_line = "    Level:       all stages cleared"
  else
    pending_line = "    Level:       still to pass - " .. table.concat(pending_names, ", ")
  end
  lines[#lines + 1] = pending_line
  highlights[#highlights + 1] = { #lines - 1, 17, #pending_line, #pending_names == 0 and "SplitTyperGood" or "SplitTyperOk" }

  if stage_prog.best_wpm > 0 then
    local best_line = string.format("    Stage best:  %d WPM, %.0f%% accuracy", stage_prog.best_wpm, stage_prog.best_accuracy)
    lines[#lines + 1] = best_line
    highlights[#highlights + 1] = { #lines - 1, 17, #best_line, "SplitTyperScore" }
  end

  lines[#lines + 1] = ""
  local sep2 = string.rep("\u{2500}", 60)
  lines[#lines + 1] = sep2
  highlights[#highlights + 1] = { #lines - 1, 0, #sep2, "SplitTyperSep" }
  lines[#lines + 1] = ""

  local next_label
  if level_complete and level_id < #ctx.course.levels then
    next_label = "    [n] Start next level"
  elseif #pending > 0 then
    next_label = "    [n] Next exercise (auto-pick stage)"
  else
    next_label = "    [n] Replay a random stage"
  end
  lines[#lines + 1] = next_label
  lines[#lines + 1] = string.format("    [r] Retry same stage (%s)", stage.name)
  lines[#lines + 1] = "    [c] Back to course"
  lines[#lines + 1] = "    [q] Quit"

  for i = #lines - 4, #lines - 1 do
    highlights[#highlights + 1] = { i, 4, 7, "SplitTyperMenuKey" }
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

  ctx.window.clear_keymaps(state)
  ctx.window.map(state, "n", function()
    if level_complete and level_id < #ctx.course.levels then
      ctx.actions.start_course_exercise(level_id + 1)
    else
      ctx.actions.start_course_exercise(level_id)
    end
  end)
  ctx.window.map(state, "r", function()
    ctx.actions.start_course_exercise(level_id, stage_id)
  end)
  ctx.window.map(state, "c", ctx.actions.show_course)
  ctx.window.map(state, "<Esc>", ctx.actions.show_course)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_combo_menu(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "combo_menu"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local cats = ctx.exercises.get_combo_categories()
  local lines = {}
  local highlights = {}

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       COMBO TRAINER"
  lines[#lines + 1] = "       Practice modifier key combinations"
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }

  local sep = string.rep("\u{2500}", 60)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Modifier key detection requires a modern terminal"
  lines[#lines + 1] = "  (kitty, wezterm, alacritty). Press Space to skip"
  lines[#lines + 1] = "  any combo your terminal can't send."
  highlights[#highlights + 1] = { #lines - 3, 0, #lines[#lines - 2], "SplitTyperMenuDesc" }
  highlights[#highlights + 1] = { #lines - 2, 0, #lines[#lines - 1], "SplitTyperMenuDesc" }
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = ""

  local cat_keys = {}
  for i, cat in ipairs(cats) do
    local key = i == 10 and "0" or tostring(i)
    cat_keys[cat.id] = key
    local line = string.format("  [%s]  %-28s %s", key, cat.name, cat.description)
    lines[#lines + 1] = line
    highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
    highlights[#highlights + 1] = { #lines - 1, 34, #line, "SplitTyperMenuDesc" }
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [Esc] Back to menu    [q] Quit"

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

  ctx.window.clear_keymaps(state)
  for _, cat in ipairs(cats) do
    local key = cat_keys[cat.id]
    if key then
      ctx.window.map(state, key, function()
        ctx.actions.start_combo_exercise(cat.id)
      end)
    end
  end
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_combo_results(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "combo_results"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local stats = ctx.state_mod.get_combo_stats(state)
  local rating, rating_hl
  if stats.score >= 200 then
    rating, rating_hl = "MASTER", "SplitTyperGood"
  elseif stats.score >= 150 then
    rating, rating_hl = "Excellent", "SplitTyperGood"
  elseif stats.score >= 100 then
    rating, rating_hl = "Great", "SplitTyperGood"
  elseif stats.score >= 60 then
    rating, rating_hl = "Good", "SplitTyperOk"
  elseif stats.score >= 30 then
    rating, rating_hl = "Decent", "SplitTyperOk"
  elseif stats.score >= 15 then
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
  add("       COMBO EXERCISE COMPLETE")
  hl(0, #lines[#lines], "SplitTyperTitle")
  add("")
  local sep = string.rep("\u{2500}", 50)
  add(sep)
  hl(0, #sep, "SplitTyperSep")
  add("")
  add(string.format("    Combos/min:  %d", stats.cpm))
  hl(17, #lines[#lines], stats.cpm >= 40 and "SplitTyperGood" or (stats.cpm >= 20 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Accuracy:    %.1f%%", stats.accuracy))
  hl(17, #lines[#lines], stats.accuracy >= 95 and "SplitTyperGood" or (stats.accuracy >= 80 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Correct:     %d / %d", stats.correct, stats.total))
  hl(17, #lines[#lines], stats.correct == stats.total and "SplitTyperGood" or "SplitTyperOk")
  add(string.format("    Errors:      %d", stats.errors))
  hl(17, #lines[#lines], stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood")
  add(string.format("    Best streak: %d", stats.best_streak))
  hl(17, #lines[#lines], stats.best_streak >= stats.total and "SplitTyperGood" or (stats.best_streak >= 10 and "SplitTyperOk" or "SplitTyperStats"))
  add(string.format("    Time:        %s", ctx.state_mod.format_time(stats.time)))
  add("")
  add(string.format("    Score:       %d", stats.score))
  hl(17, #lines[#lines], "SplitTyperScore")
  add(string.format("    Rating:      %s", rating))
  hl(17, #lines[#lines], rating_hl)

  if state.timed_mode then
    local session_chars = ctx.errs.get_session_worst_chars(state.error_log, 4)
    local session_bigrams = ctx.errs.get_session_worst_bigrams(state.error_log, state.char_map, 4, state.pos)
    local decay = ctx.errs.get_session_decay(state.key_events)

    if decay then
      add("")
      add(string.rep("\u{2500}", 44))
      hl(0, #lines[#lines], "SplitTyperSep")
      add("")
      add("    First half vs second half:")
      hl(0, #lines[#lines], "SplitTyperSep")

      local first_line = string.format(
        "      First:  %d WPM  %.1f%% acc  %.1f%% eff",
        math.floor(decay.first.wpm),
        decay.first.accuracy,
        decay.first.efficiency
      )
      add(first_line)
      hl(6, 11, "SplitTyperStats")

      local second_line = string.format(
        "      Second: %d WPM  %.1f%% acc  %.1f%% eff",
        math.floor(decay.second.wpm),
        decay.second.accuracy,
        decay.second.efficiency
      )
      add(second_line)
      hl(6, 12, "SplitTyperStats")

      local drift_hl = "SplitTyperGood"
      if decay.accuracy_delta < -3 or decay.efficiency_delta < -5 or decay.wpm_delta < -5 then
        drift_hl = "SplitTyperBad"
      elseif decay.accuracy_delta < -1 or decay.efficiency_delta < -2 or decay.wpm_delta < -2 then
        drift_hl = "SplitTyperOk"
      end
      local drift_line = string.format(
        "      Drift:  %+d WPM  %+0.1f acc  %+0.1f eff",
        math.floor(decay.wpm_delta),
        decay.accuracy_delta,
        decay.efficiency_delta
      )
      add(drift_line)
      hl(6, #lines[#lines], drift_hl)
    end

    if #session_chars > 0 or #session_bigrams > 0 then
      add("")
      add(string.rep("\u{2500}", 44))
      hl(0, #lines[#lines], "SplitTyperSep")
      add("")
      add("    Timed postmortem:")
      hl(0, #lines[#lines], "SplitTyperSep")

      if #session_chars > 0 then
        add("      Worst keys:")
        hl(6, #lines[#lines], "SplitTyperPending")
        for _, item in ipairs(session_chars) do
          local name = item.char == " " and "Space" or item.char
          add(string.format("        '%s'  %dx", name, item.count))
          hl(8, 11, "SplitTyperBad")
        end
      end

      if #session_bigrams > 0 then
        add("      Worst bigrams:")
        hl(6, #lines[#lines], "SplitTyperPending")
        for _, item in ipairs(session_bigrams) do
          add(string.format("        %s  %.0f%% (%d/%d)", item.bigram, item.error_rate * 100, item.errors, item.total))
          hl(8, 10, "SplitTyperBad")
        end
      end
    end
  end

  if #state.error_log > 0 then
    add("")
    add(sep)
    hl(0, #sep, "SplitTyperSep")
    add("")
    add("    Mistakes:")
    hl(0, #lines[#lines], "SplitTyperSep")
    add("")
    for i, err in ipairs(state.error_log) do
      if i > 10 then
        add(string.format("    ... and %d more", #state.error_log - 10))
        hl(0, #lines[#lines], "SplitTyperPending")
        break
      end
      local line = string.format("      Expected %-16s  pressed %s", err.expected_display, err.actual_display)
      add(line)
      highlights[#highlights + 1] = { #lines - 1, 6, 15 + #err.expected_display, "SplitTyperOk" }
      highlights[#highlights + 1] = { #lines - 1, #line - #err.actual_display, #line, "SplitTyperBad" }
    end
  end

  add("")
  add(sep)
  hl(0, #sep, "SplitTyperSep")
  add("")
  add("    [n] Next exercise")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [r] Retry (new random set)")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [m] Back to combo menu")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [q] Quit")
  hl(4, 7, "SplitTyperMenuKey")
  add("")

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

  ctx.window.clear_keymaps(state)
  ctx.window.map(state, "n", function()
    ctx.actions.start_combo_exercise(state.category_id)
  end)
  ctx.window.map(state, "r", function()
    ctx.actions.start_combo_exercise(state.category_id)
  end)
  ctx.window.map(state, "m", ctx.actions.show_combo_menu)
  ctx.window.map(state, "<Esc>", ctx.actions.show_combo_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_reaction_menu(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "reaction_menu"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local cats = ctx.exercises.get_reaction_categories()
  local lines = {}
  local highlights = {}

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       CHARACTER REACTION"
  lines[#lines + 1] = "       One prompt at a time, measured for correctness and reaction speed"
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }
  lines[#lines + 1] = "  Each session runs for 50 characters."
  lines[#lines + 1] = "  The timer starts on your first keypress, not when the screen opens."
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines - 1], "SplitTyperMenuDesc" }
  highlights[#highlights + 1] = { #lines, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = ""

  local sep = string.rep("─", 68)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""

  local cat_keys = {}
  for i, cat in ipairs(cats) do
    local key = tostring(i)
    cat_keys[cat.id] = key
    local line = string.format("  [%s]  %-28s %s", key, cat.name, cat.description)
    lines[#lines + 1] = line
    highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
    highlights[#highlights + 1] = { #lines - 1, 34, #line, "SplitTyperMenuDesc" }
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [Esc] Back to menu    [q] Quit"

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

  ctx.window.clear_keymaps(state)
  for _, cat in ipairs(cats) do
    local key = cat_keys[cat.id]
    if key then
      ctx.window.map(state, key, function()
        ctx.actions.start_reaction_exercise(cat.id)
      end)
    end
  end
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_reaction_results(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "reaction_results"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local stats = ctx.state_mod.get_reaction_stats(state)
  local rating, rating_hl
  if stats.accuracy >= 98 and stats.avg_reaction_ms > 0 and stats.avg_reaction_ms <= 450 then
    rating, rating_hl = "Sharp", "SplitTyperGood"
  elseif stats.accuracy >= 95 and stats.avg_reaction_ms <= 650 then
    rating, rating_hl = "Strong", "SplitTyperGood"
  elseif stats.accuracy >= 90 and stats.avg_reaction_ms <= 850 then
    rating, rating_hl = "Solid", "SplitTyperOk"
  elseif stats.accuracy >= 80 then
    rating, rating_hl = "Building", "SplitTyperOk"
  else
    rating, rating_hl = "Slow down and clean it up", "SplitTyperBad"
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
  add("       CHARACTER REACTION COMPLETE")
  hl(0, #lines[#lines], "SplitTyperTitle")
  add("")
  local sep = string.rep("─", 50)
  add(sep)
  hl(0, #sep, "SplitTyperSep")
  add("")
  add(string.format("    Chars/min:        %d", stats.cpm))
  hl(21, #lines[#lines], stats.cpm >= 90 and "SplitTyperGood" or (stats.cpm >= 60 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Accuracy:         %.1f%%", stats.accuracy))
  hl(21, #lines[#lines], stats.accuracy >= 95 and "SplitTyperGood" or (stats.accuracy >= 85 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Correct:          %d / %d", stats.correct, stats.total))
  hl(21, #lines[#lines], stats.correct == stats.total and "SplitTyperGood" or "SplitTyperOk")
  add(string.format("    Errors:           %d", stats.errors))
  hl(21, #lines[#lines], stats.errors == 0 and "SplitTyperGood" or "SplitTyperBad")
  add(string.format("    Avg reaction:     %d ms", stats.avg_reaction_ms))
  hl(21, #lines[#lines], stats.avg_reaction_ms <= 500 and "SplitTyperGood" or (stats.avg_reaction_ms <= 800 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Avg clean react:  %d ms", stats.avg_correct_reaction_ms))
  hl(21, #lines[#lines], stats.avg_correct_reaction_ms <= 500 and "SplitTyperGood" or (stats.avg_correct_reaction_ms <= 800 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Best clean:       %d ms", stats.best_reaction_ms))
  hl(21, #lines[#lines], "SplitTyperStats")
  add(string.format("    Best streak:      %d", stats.best_streak))
  hl(21, #lines[#lines], stats.best_streak >= 20 and "SplitTyperGood" or "SplitTyperStats")
  add(string.format("    Time:             %s", ctx.state_mod.format_time(stats.time)))
  add("")
  add(string.format("    Score:            %d", stats.score))
  hl(21, #lines[#lines], "SplitTyperScore")
  add(string.format("    Rating:           %s", rating))
  hl(21, #lines[#lines], rating_hl)

  if #state.error_log > 0 then
    add("")
    add(sep)
    hl(0, #sep, "SplitTyperSep")
    add("")
    add("    Mistakes:")
    hl(0, #lines[#lines], "SplitTyperSep")
    local err_lines, err_highlights = ctx.errs.format_session_errors(state.error_log)
    local base = #lines
    for _, line in ipairs(err_lines) do
      add(line)
    end
    for _, h in ipairs(err_highlights) do
      highlights[#highlights + 1] = { base + h[1], h[2], h[3], h[4] }
    end
  end

  add("")
  add(sep)
  hl(0, #sep, "SplitTyperSep")
  add("")
  add("    [n] Repeat same category")
  hl(4, 7, "SplitTyperMenuKey")
  add("    [r] Reaction menu")
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
  if state.ns then
    for _, h in ipairs(highlights) do
      pcall(vim.api.nvim_buf_set_extmark, state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  ctx.window.clear_keymaps(state)
  ctx.window.map(state, "n", function()
    ctx.actions.start_reaction_exercise(state.category_id)
  end)
  ctx.window.map(state, "r", ctx.actions.show_reaction_menu)
  ctx.window.map(state, "m", ctx.actions.show_menu)
  ctx.window.map(state, "s", ctx.actions.show_dashboard)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<Esc>", ctx.actions.show_reaction_menu)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_transition_menu(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "transition_menu"
  state.mode = "freeplay"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local lines = {}
  local highlights = {}
  local options = {
    { key = "a", class_id = nil, name = "Auto Focus", description = "Use your single weakest movement class automatically" },
  }
  local class_stats = {}
  for _, item in ipairs(ctx.errs.get_worst_transition_classes(20, 1)) do
    class_stats[item.class_id] = item
  end
  for _, item in ipairs(ctx.errs.get_transition_class_catalog()) do
    options[#options + 1] = {
      key = tostring(#options),
      class_id = item.id,
      name = item.name,
      description = item.description,
      stat = class_stats[item.id],
    }
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       WEAK TRANSITIONS"
  lines[#lines + 1] = "       Train adaptive movement patterns instead of isolated keys"
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }

  local top_class = ctx.errs.get_worst_transition_classes(1, 10, { weighted = true })[1]
  if top_class then
    lines[#lines + 1] = string.format(
      "  Auto currently favors: %s (score %.3f, sample '%s')",
      top_class.name,
      top_class.auto_score or 0,
      top_class.sample
    )
  else
    lines[#lines + 1] = "  Not enough transition data yet. Auto will fall back to weak-key practice."
  end
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], top_class and "SplitTyperMenuDesc" or "SplitTyperPending" }
  lines[#lines + 1] = ""

  local sep = string.rep("\u{2500}", 72)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""

  for _, option in ipairs(options) do
    local desc = option.description
    if option.stat then
      desc = string.format("%s  [%.0f%%, sample '%s']", desc, option.stat.error_rate * 100, option.stat.sample)
    elseif option.class_id then
      desc = desc .. "  [no data yet]"
    end
    local line = string.format("  [%s]  %-20s %s", option.key, option.name, desc)
    lines[#lines + 1] = line
    highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
    highlights[#highlights + 1] = { #lines - 1, 27, #line, option.stat and "SplitTyperMenuDesc" or "SplitTyperPending" }
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [Esc] Back to menu    [q] Quit"

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  if state.ns then
    for _, h in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  ctx.window.clear_keymaps(state)
  for _, option in ipairs(options) do
    ctx.window.map(state, option.key, function()
      ctx.actions.start_transition_exercise(option.class_id)
    end)
  end
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

local function push_section_separator(lines, highlights, title)
  local label = " \u{2500}\u{2500}\u{2500} " .. title .. " "
  local tail = math.max(3, 50 - vim.fn.strdisplaywidth(label))
  local sep = label .. string.rep("\u{2500}", tail)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
end

local function push_menu_entry(lines, highlights, key, name, description)
  local line = string.format("  [%s]  %-28s %s", key, name, description or "")
  lines[#lines + 1] = line
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #line, "SplitTyperMenuDesc" }
end

local function push_strictness_header(lines, highlights, state, state_mod)
  local mode = state.strictness or "normal"
  local label = state_mod.strictness_label(mode)
  local hint = state_mod.strictness_hint(mode)
  local line = "       Strictness: " .. label .. "  [.] cycle \u{00B7} " .. hint
  lines[#lines + 1] = line
  highlights[#highlights + 1] = { #lines - 1, 0, #line, "SplitTyperHeader" }
end

function M.show_menu(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "menu"
  state.mode = "freeplay"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local lines = {}
  local highlights = {}

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       SPLIT TYPER"
  lines[#lines + 1] = "       Adaptive Touch Typing"
  local layouts = require("split-typer.layouts")
  local layout_name = (layouts.active and layouts.active.display_name) or "QWERTY"
  lines[#lines + 1] = "       Layout: " .. layout_name
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }
  highlights[#highlights + 1] = { 3, 0, #lines[4], "SplitTyperHeader" }
  push_strictness_header(lines, highlights, state, ctx.state_mod)
  lines[#lines + 1] = ""

  push_section_separator(lines, highlights, "Practice")

  local current_level = ctx.course.get_current_level()
  local level = ctx.course.get_level(current_level)
  local progress = ctx.course.get_level_progress(current_level)
  local stages_passed = 0
  for _, sd in ipairs(ctx.course.stage_defs) do
    local sp = progress.stages and progress.stages[sd.id]
    if sp and sp.passed then stages_passed = stages_passed + 1 end
  end
  local course_status = progress.passed and current_level == #ctx.course.levels
      and "All levels complete!"
      or string.format("Level %d: %s (%d/%d stages)", current_level, level.name, stages_passed, #ctx.course.stage_defs)
  push_menu_entry(lines, highlights, "c", "Touch Typing Course", course_status)

  local targeted_desc = "(not enough data yet)"
  if ctx.errs.has_enough_data() then
    local worst = ctx.errs.get_worst_chars(3, 15)
    if #worst > 0 then
      local parts = {}
      for _, wc in ipairs(worst) do
        parts[#parts + 1] = string.format("'%s' %.0f%%", wc.char, wc.error_rate * 100)
      end
      targeted_desc = "Targeting: " .. table.concat(parts, ", ")
    end
  end
  push_menu_entry(lines, highlights, "t", "Weak Key Practice", targeted_desc)

  local transition_desc = "(not enough transition data yet)"
  if ctx.errs.has_enough_transition_data() then
    local worst = ctx.errs.get_worst_bigrams(3, 10)
    local classes = ctx.errs.get_worst_transition_classes(1, 20, { weighted = true })
    if #worst > 0 then
      local parts = {}
      for _, wb in ipairs(worst) do
        parts[#parts + 1] = string.format("'%s' %.0f%%", wb.bigram, wb.error_rate * 100)
      end
      transition_desc = "Targeting: " .. table.concat(parts, ", ")
      if #classes > 0 then
        transition_desc = classes[1].name .. " focus; " .. transition_desc
      end
    end
  end
  push_menu_entry(lines, highlights, "w", "Weak Transitions", transition_desc)
  push_menu_entry(lines, highlights, "d", "Timed Practice", "Adaptive 1-5 minute endurance sessions")
  push_menu_entry(lines, highlights, "k", "Combo Trainer", "Practice Ctrl, Alt and modifier combos")
  push_menu_entry(lines, highlights, "x", "Character Reaction", "Single-key bracket/symbol drill, 50 prompts")
  push_menu_entry(lines, highlights, "s", "Stats Dashboard", "View your typing profile")
  lines[#lines + 1] = ""

  push_section_separator(lines, highlights, "Free Play")

  local groups = ctx.exercises.get_groups()
  local group_keys = {}
  for i, group in ipairs(groups) do
    local key = tostring(i)
    group_keys[group.id] = key
    push_menu_entry(lines, highlights, key, group.name, group.description)
  end
  lines[#lines + 1] = ""

  local bottom_sep = string.rep("\u{2500}", 50)
  lines[#lines + 1] = bottom_sep
  highlights[#highlights + 1] = { #lines - 1, 0, #bottom_sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [q] Quit"

  render_buffer(state, lines, highlights)

  ctx.window.clear_keymaps(state)
  ctx.window.map(state, "c", ctx.actions.show_course)
  ctx.window.map(state, "s", ctx.actions.show_dashboard)
  ctx.window.map(state, "t", function()
    if ctx.errs.has_enough_data() then
      ctx.actions.start_targeted_exercise()
    end
  end)
  ctx.window.map(state, "w", ctx.actions.show_transition_menu)
  ctx.window.map(state, "k", ctx.actions.show_combo_menu)
  ctx.window.map(state, "x", ctx.actions.show_reaction_menu)
  ctx.window.map(state, "d", ctx.actions.show_timed_menu)
  ctx.window.map(state, ".", ctx.actions.cycle_strictness)
  for _, group in ipairs(groups) do
    local key = group_keys[group.id]
    if key then
      ctx.window.map(state, key, function()
        ctx.actions.show_group(group.id)
      end)
    end
  end
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<Esc>", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_group(ctx, group_id)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "group"
  state.group_id = group_id
  state.mode = "freeplay"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local group = ctx.exercises.get_group(group_id)
  local categories = ctx.exercises.get_categories_in_group(group_id)

  local lines = {}
  local highlights = {}

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       " .. (group and group.name:upper() or "FREE PLAY")
  lines[#lines + 1] = "       " .. (group and group.description or "")
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }
  push_strictness_header(lines, highlights, state, ctx.state_mod)
  lines[#lines + 1] = ""

  push_section_separator(lines, highlights, "Exercises")

  local reserved = { q = true }
  local key_pool = build_menu_key_pool(reserved)
  local cat_keys = {}
  for idx, cat in ipairs(categories) do
    local key = key_pool[idx] or "?"
    cat_keys[cat.id] = key
    push_menu_entry(lines, highlights, key, cat.name, cat.description)
  end
  lines[#lines + 1] = ""

  local bottom_sep = string.rep("\u{2500}", 50)
  lines[#lines + 1] = bottom_sep
  highlights[#highlights + 1] = { #lines - 1, 0, #bottom_sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [Esc] Back    [q] Quit"

  render_buffer(state, lines, highlights)

  ctx.window.clear_keymaps(state)
  for _, cat in ipairs(categories) do
    local key = cat_keys[cat.id]
    if key and key ~= "?" then
      ctx.window.map(state, key, function()
        state.mode = "freeplay"
        ctx.actions.start_exercise(cat.id)
      end)
    end
  end
  ctx.window.map(state, ".", ctx.actions.cycle_strictness)
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_timed_menu(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "timed_menu"
  state.mode = "timed"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local lines = {}
  local highlights = {}
  local options = {
    { key = "1", minutes = 1, desc = "Short, sharp accuracy block" },
    { key = "2", minutes = 2, desc = "Sustained focus without fatigue" },
    { key = "3", minutes = 3, desc = "Solid endurance practice" },
    { key = "4", minutes = 4, desc = "Hard concentration set" },
    { key = "5", minutes = 5, desc = "Long-form typing stamina" },
  }

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       TIMED PRACTICE"
  lines[#lines + 1] = "       Adaptive text keeps generating until the timer runs out"
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }
  lines[#lines + 1] = "  Sessions start timing on your first keypress and bias toward weak keys."
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = ""

  local sep = string.rep("\u{2500}", 64)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""

  for _, option in ipairs(options) do
    local line = string.format("  [%s]  %-28s %s", option.key, option.minutes .. " minute", option.desc)
    lines[#lines + 1] = line
    highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
    highlights[#highlights + 1] = { #lines - 1, 34, #line, "SplitTyperMenuDesc" }
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [Esc] Back to menu    [q] Quit"

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  if state.ns then
    for _, h in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  ctx.window.clear_keymaps(state)
  for _, option in ipairs(options) do
    ctx.window.map(state, option.key, function()
      ctx.actions.start_timed_session(option.minutes)
    end)
  end
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_results(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "results"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)
  if state.timed_mode then
    start_results_input_lock(ctx)
  end

  local stats = ctx.state_mod.get_stats(state)
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
  if state.failed_early and state.fail_reason then
    add("       ACCURACY GATE MISSED")
  else
    add(state.timed_mode and "       TIMED SESSION COMPLETE" or "       EXERCISE COMPLETE")
  end
  hl(0, #lines[#lines], "SplitTyperTitle")
  add("")
  local sep = string.rep("\u{2500}", 44)
  add(sep)
  hl(0, #sep, "SplitTyperSep")
  add("")
  add(string.format("    Net WPM:     %d", stats.wpm))
  hl(17, #lines[#lines], stats.wpm >= 60 and "SplitTyperGood" or (stats.wpm >= 30 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Gross WPM:   %d", stats.gross_wpm))
  hl(17, #lines[#lines], "SplitTyperStats")
  add(string.format("    Accuracy:    %.1f%%", stats.accuracy))
  hl(17, #lines[#lines], stats.accuracy >= 95 and "SplitTyperGood" or (stats.accuracy >= 80 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Efficiency:  %.1f%%", stats.efficiency))
  hl(17, #lines[#lines], stats.efficiency >= 95 and "SplitTyperGood" or (stats.efficiency >= 85 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Errors:      %d", stats.errors))
  hl(17, #lines[#lines], stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood")
  add(string.format("    Backspaces:  %d", stats.backspaces))
  hl(17, #lines[#lines], stats.backspaces == 0 and "SplitTyperGood" or "SplitTyperPending")
  add(string.format("    Best streak: %d", stats.best_streak))
  hl(17, #lines[#lines], stats.best_streak >= stats.total_chars and "SplitTyperGood" or (stats.best_streak >= 20 and "SplitTyperOk" or "SplitTyperStats"))
  add(string.format("    Time:        %s", ctx.state_mod.format_time(stats.time)))
  add(string.format("    Characters:  %d", stats.typed_chars))
  add("")
  add(string.format("    Score:       %d", stats.score))
  hl(17, #lines[#lines], "SplitTyperScore")
  add(string.format("    Rating:      %s", rating))
  hl(17, #lines[#lines], rating_hl)

  if state.generated_desc and #state.generated_desc > 0 then
    add("")
    add("    Focus:       " .. state.generated_desc)
    hl(17, #lines[#lines], "SplitTyperPending")
  end

  if state.fail_reason then
    add("")
    add("    " .. state.fail_reason)
    hl(0, #lines[#lines], "SplitTyperBad")
  end

  if state.repeat_until_clean and state.failed_early then
    add("")
    add("    Repeat-until-clean is active: the same prompt should be replayed until you clear it.")
    hl(0, #lines[#lines], "SplitTyperOk")
  end

  if #state.error_log > 0 then
    add("")
    add(string.rep("\u{2500}", 44))
    hl(0, #lines[#lines], "SplitTyperSep")
    add("")
    add("    Problem keys this session:")
    hl(0, #lines[#lines], "SplitTyperSep")
    local err_lines, err_highlights = ctx.errs.format_session_errors(state.error_log)
    local base = #lines
    for _, line in ipairs(err_lines) do
      add(line)
    end
    for _, h in ipairs(err_highlights) do
      highlights[#highlights + 1] = { base + h[1], h[2], h[3], h[4] }
    end

    local typed_char_map = state.char_map
    if state.timed_mode then
      typed_char_map = {}
      for i = 1, state.pos do
        typed_char_map[i] = state.char_map[i]
      end
    end
    local session_bigrams = ctx.errs.get_session_worst_bigrams(state.error_log, typed_char_map, 3, state.pos)
    if #session_bigrams > 0 then
      add("")
      add("    Hardest transitions this session:")
      hl(0, #lines[#lines], "SplitTyperSep")
      for _, wb in ipairs(session_bigrams) do
        local class_note = ""
        if wb.class_names and #wb.class_names > 0 then
          class_note = "  " .. table.concat(wb.class_names, ", ")
        end
        local line = string.format("      '%s'  %.0f%% error rate  (%d/%d)%s", wb.bigram, wb.error_rate * 100, wb.errors, wb.total, class_note)
        add(line)
        hl(6, 10, "SplitTyperBad")
      end
    end
  end

  add("")
  add(string.rep("\u{2500}", 44))
  hl(0, #lines[#lines], "SplitTyperSep")
  if state.timed_mode then
    add_results_input_lock_notice(state, lines, highlights)
  end
  add("")
  if state.repeat_until_clean and not state.timed_mode then
    add("    [n] Repeat same prompt")
  else
    add(state.timed_mode and "    [n] New timed session" or "    [n] Next exercise")
  end
  hl(4, 7, "SplitTyperMenuKey")
  if state.repeat_until_clean and not state.timed_mode then
    add("    [r] New prompt in same category")
  else
    add(state.timed_mode and "    [r] Timed menu" or "    [r] Retry same exercise")
  end
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
  if state.ns then
    for _, h in ipairs(highlights) do
      pcall(vim.api.nvim_buf_set_extmark, state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end

  ctx.window.clear_keymaps(state)
  if state.timed_mode then
    local minutes = tonumber((state.category_id or ""):match("timed_(%d+)m"))
    map_results_action(ctx, "n", function()
      ctx.actions.start_timed_session(minutes or 1)
    end)
    map_results_action(ctx, "r", ctx.actions.show_timed_menu)
  elseif state.category_id == "targeted_practice" then
    ctx.window.map(state, "n", ctx.actions.start_targeted_exercise)
    ctx.window.map(state, "r", ctx.actions.restart_current_text)
  elseif state.category_id == "transition_practice" then
    ctx.window.map(state, "n", function()
      ctx.actions.start_transition_exercise(state.transition_focus_class)
    end)
    ctx.window.map(state, "r", ctx.actions.restart_current_text)
  elseif state.repeat_until_clean then
    ctx.window.map(state, "n", ctx.actions.restart_current_text)
    ctx.window.map(state, "r", function()
      ctx.actions.start_exercise(state.category_id)
    end)
  else
    ctx.window.map(state, "n", function()
      ctx.actions.start_exercise(state.category_id)
    end)
    ctx.window.map(state, "r", ctx.actions.restart_current_text)
  end
  if state.timed_mode then
    map_results_action(ctx, "m", ctx.actions.show_menu)
    map_results_action(ctx, "s", ctx.actions.show_dashboard)
    map_results_action(ctx, "q", ctx.actions.cleanup)
    map_results_action(ctx, "<Esc>", ctx.actions.show_menu)
  else
    ctx.window.map(state, "m", ctx.actions.show_menu)
    ctx.window.map(state, "s", ctx.actions.show_dashboard)
    ctx.window.map(state, "q", ctx.actions.cleanup)
    ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  end
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_dashboard(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "dashboard"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)
  ctx.window.clear_keymaps(state)

  local dashboard = require("split-typer.dashboard")
  dashboard.render(state.buf, state.ns, state.win, {
    on_back = ctx.actions.show_menu,
    on_quit = ctx.actions.cleanup,
    map = function(key, fn)
      ctx.window.map(state, key, fn)
    end,
    on_reset_errors = function()
      ctx.errs.reset()
      M.show_dashboard(ctx)
    end,
  })
end

return M
