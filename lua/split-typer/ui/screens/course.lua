local common = require("split-typer.ui.screens.common")

local M = {}

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

    local stage_chunks = {}
    local passed_count = 0
    for _, sd in ipairs(ctx.course.stage_defs) do
      local sp = progress.stages[sd.id] or { completed = 0, passed = false }
      local reps = 2
      for _, s in ipairs(level.stages) do
        if s.id == sd.id then
          reps = s.reps_required
          break
        end
      end
      local done = math.min(sp.completed or 0, reps)
      stage_chunks[#stage_chunks + 1] = string.format("%s:%d/%d", sd.short, done, reps)
      if sp.passed then
        passed_count = passed_count + 1
      end
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

  common.render_buffer(state, lines, highlights)

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

  local pending = ctx.course.pending_stages(level_id)
  local pending_names = {}
  for _, sid in ipairs(pending) do
    local s = ctx.course.get_stage(level_id, sid)
    if s then
      pending_names[#pending_names + 1] = s.name
    end
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

  common.render_buffer(state, lines, highlights)

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

return M
