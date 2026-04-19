local common = require("split-typer.ui.screens.common")
local coaching = require("split-typer.coaching")

local M = {}

local function course_mode_label(stage)
  if not stage then
    return "Clean"
  end
  if stage.course_mode == "guided" then
    return "Guided"
  end
  if stage.course_mode == "mastery" then
    return "Mastery"
  end
  return "Clean"
end

local function format_timestamp(ts)
  if not ts then
    return "n/a"
  end
  return os.date("%Y-%m-%d %H:%M", ts)
end

function M.show_course(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "course"
  state.mode = "course"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local levels = ctx.course.levels
  local current = ctx.course.get_focus_level()
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
  local course_coaching = coaching.build_course_overview(ctx.course, current)
  lines[#lines + 1] = course_coaching.phase_line
  highlights[#highlights + 1] = { #lines - 1, 0, #course_coaching.phase_line, course_coaching.phase_hl }
  lines[#lines + 1] = course_coaching.recommendation_line
  highlights[#highlights + 1] = { #lines - 1, 0, #course_coaching.recommendation_line, course_coaching.recommendation_hl }
  lines[#lines + 1] = ""

  local level_keys = {}
  for _, level in ipairs(levels) do
    local progress = ctx.course.get_level_progress(level.id)
    local unlocked = ctx.course.is_unlocked(level.id)
    local active_stage_defs = ctx.course.get_stage_defs(level.id)
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
    local validated_count = 0
    for _, sd in ipairs(active_stage_defs) do
      local sp = progress.stages[sd.id] or { completed = 0, passed = false, validated = false }
      local reps = 2
      local stage_mode = nil
      for _, s in ipairs(level.stages) do
        if s.id == sd.id then
          reps = s.reps_required
          stage_mode = course_mode_label(s)
          break
        end
      end
      local done = math.min(sp.completed or 0, reps)
      local mode_mark = stage_mode == "Guided" and "*"
        or (stage_mode == "Mastery" and "!" or "")
      local validation_mark = sp.validated and "v" or (sp.passed and "+" or "")
      stage_chunks[#stage_chunks + 1] = string.format("%s%s:%d/%d%s", sd.short, mode_mark, done, reps, validation_mark)
      if sp.passed then
        passed_count = passed_count + 1
      end
      if sp.validated then
        validated_count = validated_count + 1
      end
    end
    local stage_summary = table.concat(stage_chunks, " ")

    local status, status_hl
    if progress.validated then
      if progress.best_wpm > 0 then
        status = string.format("VALIDATED  best %d WPM %.0f%%", progress.best_wpm, progress.best_accuracy)
      else
        status = "VALIDATED"
      end
      status_hl = "SplitTyperGood"
    elseif progress.passed then
      status = string.format("PASSED  validate %d/%d stages", validated_count, #active_stage_defs)
      status_hl = "SplitTyperOk"
    elseif unlocked then
      status = string.format("%s  (%d/%d passed, %d/%d validated)", stage_summary, passed_count, #active_stage_defs, validated_count, #active_stage_defs)
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
  lines[#lines + 1] = "  Each level runs 5 core stage types; levels 4-12 also add a short transfer check."
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = "  + = passed and waiting on delayed validation   v = validated mastery"
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = "  * = Guided rep (corrections allowed on early mapping/transfer levels)   ! = Mastery rep"
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = "  Pressing a level key auto-picks unfinished work first, then delayed validation reps."
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
  local passed_exercise, stage_cleared, stage_validated, level_complete, level_validated = ctx.course.record_exercise(
    level_id,
    stage_id,
    stats.wpm,
    stats.accuracy,
    stats.efficiency,
    stats.errors
  )
  local level_prog = ctx.course.get_level_progress(level_id)
  local stage_prog = level_prog.stages[stage_id] or {
    completed = 0,
    passed = false,
    validated = false,
    validation_runs = 0,
    best_wpm = 0,
    best_accuracy = 0,
  }

  local lines = { "" }
  local highlights = {}
  local mode_label = course_mode_label(stage)
  local rep_label = stage.id == "transfer" and "TRANSFER CHECK PASSED"
    or (mode_label == "Guided" and "GUIDED REP PASSED"
    or (mode_label == "Mastery" and "MASTERY REP PASSED" or "CLEAN REP PASSED")
    )
  local typed_char_map = state.char_map
  local session_transition_focus = nil
  if #state.error_log > 0 then
    session_transition_focus = ctx.errs.get_session_transition_focus(state.error_log, typed_char_map, state.pos)
  end
  local coaching_info = coaching.build_session_coaching({
    course = ctx.course,
    level_id = level_id,
    stage = stage,
    stage_prog = stage_prog,
    stage_validated = stage_validated,
    level_validated = level_validated,
    passed_exercise = passed_exercise,
    validation_ready = ctx.course.is_stage_validation_ready(level_id, stage_id),
    session_transition_focus = session_transition_focus,
    stats = stats,
  })

  if level_validated then
    lines[#lines + 1] = "       LEVEL VALIDATED!"
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif level_complete then
    lines[#lines + 1] = "       LEVEL COMPLETE!"
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif stage_validated then
    lines[#lines + 1] = string.format("       STAGE VALIDATED: %s", stage.name)
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif stage_cleared then
    lines[#lines + 1] = string.format("       STAGE CLEARED: %s", stage.name)
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif passed_exercise then
    lines[#lines + 1] = "       " .. rep_label
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperOk" }
  else
    lines[#lines + 1] = "       NOT YET..."
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperBad" }
  end

  lines[#lines + 1] = string.format("       Level %d: %s  -  %s", level_id, level.name, stage.name)
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperHeader" }
  lines[#lines + 1] = string.format("       Course mode: %s", mode_label)
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], mode_label == "Guided" and "SplitTyperOk" or "SplitTyperHeader" }
  if stage_prog.passed and not stage_prog.validated then
    local due_at = ctx.course.get_stage_validation_due_at(level_id, stage_id)
    local validation_line
    if ctx.course.is_stage_validation_ready(level_id, stage_id) then
      validation_line = "       Validation: ready now - one more successful run will validate this stage"
    else
      validation_line = "       Validation: opens at " .. format_timestamp(due_at)
    end
    lines[#lines + 1] = validation_line
    highlights[#highlights + 1] = { #lines - 1, 0, #validation_line, "SplitTyperMenuDesc" }
  elseif stage_prog.validated then
    local validation_line = "       Validated at: " .. format_timestamp(stage_prog.validated_at)
    lines[#lines + 1] = validation_line
    highlights[#highlights + 1] = { #lines - 1, 0, #validation_line, "SplitTyperMenuDesc" }
  end
  lines[#lines + 1] = coaching_info.phase_line
  highlights[#highlights + 1] = { #lines - 1, 0, #coaching_info.phase_line, coaching_info.phase_hl }
  lines[#lines + 1] = coaching_info.recommendation_line
  highlights[#highlights + 1] = { #lines - 1, 0, #coaching_info.recommendation_line, coaching_info.recommendation_hl }

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
  local policy_line = string.format(
    "    Policy:      %s",
    stage.id == "transfer" and (mode_label == "Guided"
        and "short real-text exposure; corrections allowed while transfer is new"
      or "short real-text transfer check - no backspace")
      or (mode_label == "Guided" and "corrections allowed while the key map is still settling"
        or (mode_label == "Mastery" and "clean run required - no backspace"
          or "clean run - no backspace"))
  )
  lines[#lines + 1] = policy_line
  highlights[#highlights + 1] = { #lines - 1, 17, #policy_line, "SplitTyperSep" }

  local stage_line = string.format("    %s:    %d/%d passes", stage.name, math.min(stage_prog.completed, stage.reps_required), stage.reps_required)
  lines[#lines + 1] = stage_line
  highlights[#highlights + 1] = { #lines - 1, 17, #stage_line, stage_prog.passed and "SplitTyperGood" or "SplitTyperOk" }
  local validation_status
  local validation_hl
  if stage_prog.validated then
    validation_status = string.format("    Validation: %d run(s), validated", stage_prog.validation_runs or 0)
    validation_hl = "SplitTyperGood"
  elseif stage_prog.passed then
    local due_at = ctx.course.get_stage_validation_due_at(level_id, stage_id)
    if ctx.course.is_stage_validation_ready(level_id, stage_id) then
      validation_status = "    Validation: ready now - pass once more to validate"
    else
      validation_status = "    Validation: pending until " .. format_timestamp(due_at)
    end
    validation_hl = "SplitTyperOk"
  else
    validation_status = "    Validation: unlocks after the stage is passed"
    validation_hl = "SplitTyperPending"
  end
  lines[#lines + 1] = validation_status
  highlights[#highlights + 1] = { #lines - 1, 17, #validation_status, validation_hl }

  local pending = ctx.course.pending_stages(level_id)
  local pending_validation = ctx.course.pending_validation_stages(level_id)
  local active_stage_defs = ctx.course.get_stage_defs(level_id)
  local pending_names = {}
  for _, sid in ipairs(pending) do
    local s = ctx.course.get_stage(level_id, sid)
    if s then
      pending_names[#pending_names + 1] = s.name
    end
  end
  local pending_validation_names = {}
  for _, sid in ipairs(pending_validation) do
    local s = ctx.course.get_stage(level_id, sid)
    if s then
      pending_validation_names[#pending_validation_names + 1] = s.name
    end
  end
  local pending_line
  if #pending_names == 0 then
    pending_line = "    Level:       all stages passed"
  else
    pending_line = "    Level:       still to pass - " .. table.concat(pending_names, ", ")
  end
  lines[#lines + 1] = pending_line
  highlights[#highlights + 1] = { #lines - 1, 17, #pending_line, #pending_names == 0 and "SplitTyperGood" or "SplitTyperOk" }
  local validation_line
  if #pending_validation_names == 0 then
    validation_line = "    Mastery:     all delayed validations done"
  else
    validation_line = "    Mastery:     still to validate - " .. table.concat(pending_validation_names, ", ")
  end
  lines[#lines + 1] = validation_line
  highlights[#highlights + 1] = { #lines - 1, 17, #validation_line, #pending_validation_names == 0 and "SplitTyperGood" or "SplitTyperOk" }
  local stage_count_line = string.format("    Stage set:   %d active stages on this level", #active_stage_defs)
  lines[#lines + 1] = stage_count_line
  highlights[#highlights + 1] = { #lines - 1, 17, #stage_count_line, "SplitTyperMenuDesc" }

  if stage_prog.best_wpm > 0 then
    local best_line = string.format("    Stage best:  %d WPM, %.0f%% accuracy", stage_prog.best_wpm, stage_prog.best_accuracy)
    lines[#lines + 1] = best_line
    highlights[#highlights + 1] = { #lines - 1, 17, #best_line, "SplitTyperScore" }
  end

  if not passed_exercise and session_transition_focus and session_transition_focus.class_id then
    lines[#lines + 1] = ""
    local reinforce_sep = string.rep("\u{2500}", 60)
    lines[#lines + 1] = reinforce_sep
    highlights[#highlights + 1] = { #lines - 1, 0, #reinforce_sep, "SplitTyperSep" }
    lines[#lines + 1] = ""
    local reinforce_line = string.format(
      "    Reinforcement: %s via %s",
      session_transition_focus.class_name,
      table.concat(vim.tbl_map(function(bg)
        return "'" .. bg .. "'"
      end, session_transition_focus.transitions), ", ")
    )
    lines[#lines + 1] = reinforce_line
    highlights[#highlights + 1] = { #lines - 1, 20, #reinforce_line, "SplitTyperOk" }
    lines[#lines + 1] = "    [w] Run a short transition reinforcement drill from this failure pattern"
    highlights[#highlights + 1] = { #lines - 1, 4, 7, "SplitTyperMenuKey" }
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
  elseif #pending_validation > 0 then
    next_label = "    [n] Next validation rep"
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
  if not passed_exercise and session_transition_focus and session_transition_focus.class_id then
    ctx.window.map(state, "w", function()
      ctx.actions.start_transition_reinforcement(
        session_transition_focus.class_id,
        session_transition_focus.transitions
      )
    end)
  end
  ctx.window.map(state, "c", ctx.actions.show_course)
  ctx.window.map(state, "<Esc>", ctx.actions.show_course)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

return M
