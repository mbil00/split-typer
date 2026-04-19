local common = require("split-typer.ui.screens.common")

local M = {}

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

  common.render_buffer(state, lines, highlights)

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

  common.render_buffer(state, lines, highlights)

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

function M.show_results(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "results"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)
  if state.timed_mode then
    common.start_results_input_lock(ctx)
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
  add(string.format("    Uncorrected: %.1f%%", stats.uncorrected_accuracy))
  hl(17, #lines[#lines], stats.uncorrected_accuracy >= 95 and "SplitTyperGood" or (stats.uncorrected_accuracy >= 80 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Corrected:   %.1f%%", stats.corrected_accuracy))
  hl(17, #lines[#lines], stats.corrected_accuracy >= 95 and "SplitTyperGood" or (stats.corrected_accuracy >= 85 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Errors:      %d", stats.errors))
  hl(17, #lines[#lines], stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood")
  add(string.format("    Backspaces:  %d", stats.backspaces))
  hl(17, #lines[#lines], stats.backspaces == 0 and "SplitTyperGood" or "SplitTyperPending")
  add(string.format("    Backsp/100:  %.1f", stats.backspaces_per_100_chars))
  hl(17, #lines[#lines], stats.backspaces_per_100_chars <= 3 and "SplitTyperGood" or (stats.backspaces_per_100_chars <= 8 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Errors/100:  %.1f", stats.uncorrected_errors_per_100_chars))
  hl(17, #lines[#lines], stats.uncorrected_errors_per_100_chars <= 3 and "SplitTyperGood" or (stats.uncorrected_errors_per_100_chars <= 8 and "SplitTyperOk" or "SplitTyperBad"))
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
    common.add_results_input_lock_notice(state, lines, highlights)
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

  common.render_buffer(state, lines, highlights)

  ctx.window.clear_keymaps(state)
  if state.timed_mode then
    local minutes = tonumber((state.category_id or ""):match("timed_(%d+)m"))
    common.map_results_action(ctx, "n", function()
      ctx.actions.start_timed_session(minutes or 1)
    end)
    common.map_results_action(ctx, "r", ctx.actions.show_timed_menu)
  elseif state.category_id == "targeted_practice" then
    ctx.window.map(state, "n", ctx.actions.start_targeted_exercise)
    ctx.window.map(state, "r", ctx.actions.restart_current_text)
  elseif state.category_id == "transition_practice" then
    ctx.window.map(state, "n", function()
      ctx.actions.start_transition_exercise(state.transition_focus_class)
    end)
    ctx.window.map(state, "r", ctx.actions.restart_current_text)
  elseif state.category_id == "course_transition_reinforcement" then
    ctx.window.map(state, "n", function()
      ctx.actions.start_transition_reinforcement(
        state.transition_focus_class,
        state.transition_focus_transitions
      )
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
    common.map_results_action(ctx, "m", ctx.actions.show_menu)
    common.map_results_action(ctx, "s", ctx.actions.show_dashboard)
    common.map_results_action(ctx, "q", ctx.actions.cleanup)
    common.map_results_action(ctx, "<Esc>", ctx.actions.show_menu)
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
