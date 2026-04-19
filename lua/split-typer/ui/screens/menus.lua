local common = require("split-typer.ui.screens.common")
local coaching = require("split-typer.coaching")

local M = {}

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

  common.render_buffer(state, lines, highlights)

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

  common.render_buffer(state, lines, highlights)

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

  common.render_buffer(state, lines, highlights)

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

function M.show_benchmark_menu(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "benchmark_menu"
  state.mode = "timed"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local defs = ctx.benchmarks.get_definitions()
  local summary_by_id = {}
  for _, item in ipairs(ctx.benchmarks.get_summary()) do
    summary_by_id[item.definition.id] = item
  end

  local lines = {}
  local highlights = {}

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       BENCHMARKS"
  lines[#lines + 1] = "       Stable fixed-text checks for baseline, latest, and best performance"
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }

  local sep = string.rep("\u{2500}", 78)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  The first attempt becomes your baseline. Benchmarks are saved separately from normal practice history."
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperMenuDesc" }
  lines[#lines + 1] = ""

  for _, def in ipairs(defs) do
    local summary = summary_by_id[def.id]
    local detail = def.description
    if summary and summary.count > 0 then
      local first = summary.first
      local latest = summary.latest
      local best = summary.best
      detail = string.format(
        "%s  [baseline %d WPM %.1f%% | latest %d WPM %.1f%% | best %d WPM %.1f%%]",
        def.description,
        first and (first.wpm or 0) or 0,
        first and (first.corrected_accuracy or first.efficiency or first.accuracy or 0) or 0,
        latest and (latest.wpm or 0) or 0,
        latest and (latest.corrected_accuracy or latest.efficiency or latest.accuracy or 0) or 0,
        best and (best.wpm or 0) or 0,
        best and (best.corrected_accuracy or best.efficiency or best.accuracy or 0) or 0
      )
    end
    local line = string.format("  [%s]  %-16s %s", def.key, def.name, detail)
    lines[#lines + 1] = line
    highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
    highlights[#highlights + 1] = { #lines - 1, 23, #line, summary and summary.count > 0 and "SplitTyperMenuDesc" or "SplitTyperPending" }
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [Esc] Back to menu    [q] Quit"

  common.render_buffer(state, lines, highlights)

  ctx.window.clear_keymaps(state)
  for _, def in ipairs(defs) do
    ctx.window.map(state, def.key, function()
      ctx.actions.start_benchmark(def.id)
    end)
  end
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
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
  common.push_strictness_header(lines, highlights, state, ctx.state_mod)
  lines[#lines + 1] = ""

  common.push_section_separator(lines, highlights, "Practice")

  local current_level = ctx.course.get_focus_level()
  local level = ctx.course.get_level(current_level)
  local progress = ctx.course.get_level_progress(current_level)
  local stages_passed = 0
  local stages_validated = 0
  for _, sd in ipairs(ctx.course.stage_defs) do
    local sp = progress.stages and progress.stages[sd.id]
    if sp and sp.passed then
      stages_passed = stages_passed + 1
    end
    if sp and sp.validated then
      stages_validated = stages_validated + 1
    end
  end
  local course_status
  local course_phase = coaching.build_course_overview(ctx.course, current_level)
  if progress.validated and current_level == #ctx.course.levels then
    course_status = string.format("%s - All levels validated!", course_phase.phase)
  elseif progress.passed then
    course_status = string.format(
      "%s - Level %d: %s (%d/%d validated)",
      course_phase.phase,
      current_level,
      level.name,
      stages_validated,
      #ctx.course.stage_defs
    )
  else
    course_status = string.format(
      "%s - Level %d: %s (%d/%d passed, %d/%d validated)",
      course_phase.phase,
      current_level,
      level.name,
      stages_passed,
      #ctx.course.stage_defs,
      stages_validated,
      #ctx.course.stage_defs
    )
  end
  common.push_menu_entry(lines, highlights, "c", "Touch Typing Course", course_status)

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
  common.push_menu_entry(lines, highlights, "t", "Weak Key Practice", targeted_desc)

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
  common.push_menu_entry(lines, highlights, "w", "Weak Transitions", transition_desc)
  common.push_menu_entry(lines, highlights, "d", "Timed Practice", "Adaptive 1-5 minute endurance sessions")
  common.push_menu_entry(lines, highlights, "b", "Benchmarks", "Stable baseline and regression checks")
  common.push_menu_entry(lines, highlights, "k", "Combo Trainer", "Practice Ctrl, Alt and modifier combos")
  common.push_menu_entry(lines, highlights, "x", "Character Reaction", "Single-key bracket/symbol drill, 50 prompts")
  common.push_menu_entry(lines, highlights, "s", "Stats Dashboard", "View your typing profile")
  lines[#lines + 1] = ""

  common.push_section_separator(lines, highlights, "Free Play")

  local groups = ctx.exercises.get_groups()
  local group_keys = {}
  for i, group in ipairs(groups) do
    local key = tostring(i)
    group_keys[group.id] = key
    common.push_menu_entry(lines, highlights, key, group.name, group.description)
  end
  lines[#lines + 1] = ""

  local bottom_sep = string.rep("\u{2500}", 50)
  lines[#lines + 1] = bottom_sep
  highlights[#highlights + 1] = { #lines - 1, 0, #bottom_sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [q] Quit"

  common.render_buffer(state, lines, highlights)

  ctx.window.clear_keymaps(state)
  ctx.window.map(state, "c", ctx.actions.show_course)
  ctx.window.map(state, "s", ctx.actions.show_dashboard)
  ctx.window.map(state, "t", function()
    if ctx.errs.has_enough_data() then
      ctx.actions.start_targeted_exercise()
    end
  end)
  ctx.window.map(state, "w", ctx.actions.show_transition_menu)
  ctx.window.map(state, "b", ctx.actions.show_benchmark_menu)
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
  common.push_strictness_header(lines, highlights, state, ctx.state_mod)
  lines[#lines + 1] = ""

  common.push_section_separator(lines, highlights, "Exercises")

  local reserved = { q = true }
  local key_pool = common.build_menu_key_pool(reserved)
  local cat_keys = {}
  for idx, cat in ipairs(categories) do
    local key = key_pool[idx] or "?"
    cat_keys[cat.id] = key
    common.push_menu_entry(lines, highlights, key, cat.name, cat.description)
  end
  lines[#lines + 1] = ""

  local bottom_sep = string.rep("\u{2500}", 50)
  lines[#lines + 1] = bottom_sep
  highlights[#highlights + 1] = { #lines - 1, 0, #bottom_sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [Esc] Back    [q] Quit"

  common.render_buffer(state, lines, highlights)

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

  common.render_buffer(state, lines, highlights)

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

return M
