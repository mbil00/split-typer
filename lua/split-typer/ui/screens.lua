local M = {}

local menu_sections = {
  { title = "General", pattern = "^home_row$|^left_hand$|^right_hand$|^center_column$|^common_words$" },
  { title = "Characters", pattern = "^numbers$|^symbols$|^brackets$|^special_" },
  { title = "Code", pattern = "^code_" },
  { title = "Text", pattern = "^prose$|^mixed$" },
  { title = "Precision (no backspace)", pattern = "^precision_" },
  { title = "Finger Isolation", pattern = "^finger_" },
}

local function get_section(cat_id)
  for _, sec in ipairs(menu_sections) do
    for part in sec.pattern:gmatch("[^|]+") do
      local pat = part:gsub("^%^", ""):gsub("%$$", "")
      if pat:sub(-1) == "_" then
        if cat_id:sub(1, #pat) == pat then
          return sec.title
        end
      elseif cat_id == pat then
        return sec.title
      end
    end
  end
  return "Other"
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

  local sep = string.rep("\u{2500}", 70)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""

  local level_keys = {}
  for _, level in ipairs(levels) do
    local progress = ctx.course.get_level_progress(level.id)
    local unlocked = ctx.course.is_unlocked(level.id)
    local key = level.id < 10 and tostring(level.id) or (level.id == 10 and "0" or string.char(86 + level.id))
    if level.id == 10 then
      key = "0"
    elseif level.id == 11 then
      key = "a"
    elseif level.id == 12 then
      key = "b"
    end

    local status, status_hl
    if progress.passed then
      status = string.format("PASSED  (best: %d WPM, %.0f%%)", progress.best_wpm, progress.best_accuracy)
      status_hl = "SplitTyperGood"
    elseif unlocked then
      local max_errors = level.req_max_errors or 5
      status = string.format(
        "%d/%d done  (need: %d WPM, %.0f%%, <%d err)",
        progress.completed,
        level.req_exercises,
        level.req_wpm,
        level.req_accuracy,
        max_errors + 1
      )
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
  local sep2 = string.rep("\u{2500}", 70)
  lines[#lines + 1] = sep2
  highlights[#highlights + 1] = { #lines - 1, 0, #sep2, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Press a number to start that level"
  lines[#lines + 1] = "  [Esc] Back to menu    [q] Quit    [R] Reset progress"

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
  local level = ctx.course.get_level(level_id)
  local passed_exercise, level_complete = ctx.course.record_exercise(level_id, stats.wpm, stats.accuracy, stats.errors)
  local progress = ctx.course.get_level_progress(level_id)
  local max_errors = level.req_max_errors or 5

  local lines = { "" }
  local highlights = {}

  if level_complete then
    lines[#lines + 1] = "       LEVEL COMPLETE!"
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperGood" }
  elseif passed_exercise then
    lines[#lines + 1] = "       EXERCISE PASSED"
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperOk" }
  else
    lines[#lines + 1] = "       NOT YET..."
    highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperBad" }
  end

  lines[#lines + 1] = string.format("       Level %d: %s", level_id, level.name)
  highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperHeader" }

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
      local line = "       " .. table.concat(reasons, " | ")
      lines[#lines + 1] = line
      highlights[#highlights + 1] = { #lines - 1, 0, #line, "SplitTyperBad" }
    end
  end

  lines[#lines + 1] = ""
  local sep = string.rep("\u{2500}", 50)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""

  local wpm_line = string.format("    WPM:         %d", stats.wpm)
  local acc_line = string.format("    Accuracy:    %.1f%%", stats.accuracy)
  local err_line = string.format("    Errors:      %d", stats.errors)
  local time_line = string.format("    Time:        %s", ctx.state_mod.format_time(stats.time))
  lines[#lines + 1] = wpm_line
  lines[#lines + 1] = acc_line
  lines[#lines + 1] = err_line
  lines[#lines + 1] = time_line

  highlights[#highlights + 1] = { #lines - 4, 17, #wpm_line, stats.wpm >= level.req_wpm and "SplitTyperGood" or "SplitTyperBad" }
  highlights[#highlights + 1] = { #lines - 3, 17, #acc_line, stats.accuracy >= level.req_accuracy and "SplitTyperGood" or "SplitTyperBad" }
  highlights[#highlights + 1] = { #lines - 2, 17, #err_line, stats.errors <= max_errors and "SplitTyperGood" or "SplitTyperBad" }

  lines[#lines + 1] = ""
  local req_line = string.format("    Required:    %d WPM, %.0f%% acc, %d max errors", level.req_wpm, level.req_accuracy, max_errors)
  lines[#lines + 1] = req_line
  highlights[#highlights + 1] = { #lines - 1, 17, #req_line, "SplitTyperSep" }

  local progress_line = string.format("    Progress:    %d/%d exercises passed", progress.completed, level.req_exercises)
  lines[#lines + 1] = progress_line
  highlights[#highlights + 1] = { #lines - 1, 17, #progress_line, progress.passed and "SplitTyperGood" or "SplitTyperOk" }

  if progress.best_wpm > 0 then
    local best_line = string.format("    Best:        %d WPM, %.0f%% accuracy", progress.best_wpm, progress.best_accuracy)
    lines[#lines + 1] = best_line
    highlights[#highlights + 1] = { #lines - 1, 17, #best_line, "SplitTyperScore" }
  end

  lines[#lines + 1] = ""
  local sep2 = string.rep("\u{2500}", 50)
  lines[#lines + 1] = sep2
  highlights[#highlights + 1] = { #lines - 1, 0, #sep2, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = level_complete and level_id < #ctx.course.levels
      and "    [n] Start next level"
      or "    [n] Next exercise (same level)"
  lines[#lines + 1] = "    [r] Retry (new random exercise)"
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
    ctx.actions.start_course_exercise(level_complete and level_id < #ctx.course.levels and level_id + 1 or level_id)
  end)
  ctx.window.map(state, "r", function()
    ctx.actions.start_course_exercise(level_id)
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

function M.show_menu(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "menu"
  state.mode = "freeplay"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

  local cats = ctx.exercises.get_categories()
  local groups = {}
  local order = {}
  for _, cat in ipairs(cats) do
    local section = get_section(cat.id)
    if not groups[section] then
      groups[section] = {}
      order[#order + 1] = section
    end
    groups[section][#groups[section] + 1] = cat
  end

  local reserved = { q = true, c = true, s = true, t = true, k = true }
  local key_pool = {}
  for i = 1, 9 do
    key_pool[#key_pool + 1] = tostring(i)
  end
  key_pool[#key_pool + 1] = "0"
  for ch = string.byte("a"), string.byte("z") do
    local key = string.char(ch)
    if not reserved[key] then
      key_pool[#key_pool + 1] = key
    end
  end
  for _, extra in ipairs({ "A", "B", "C", "D", "E" }) do
    key_pool[#key_pool + 1] = extra
  end

  local key_idx = 0
  local cat_keys = {}
  local lines = {}
  local highlights = {}

  lines[#lines + 1] = ""
  lines[#lines + 1] = "       SPLIT TYPER"
  lines[#lines + 1] = "       Ergodox EZ Practice"
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }

  local current_level = ctx.course.get_current_level()
  local level = ctx.course.get_level(current_level)
  local progress = ctx.course.get_level_progress(current_level)
  local course_status = progress.passed and current_level == #ctx.course.levels
      and "All levels complete!"
      or string.format("Level %d: %s (%d/%d)", current_level, level.name, progress.completed, level.req_exercises)

  local course_sep = " " .. string.rep("\u{2500}", 3) .. " Course " .. string.rep("\u{2500}", 34)
  lines[#lines + 1] = course_sep
  highlights[#highlights + 1] = { #lines - 1, 0, #course_sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  local course_line = string.format("  [c]  %-28s %s", "Touch Typing Course", course_status)
  lines[#lines + 1] = course_line
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #course_line, "SplitTyperMenuDesc" }

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
  local targeted_line = string.format("  [t]  %-28s %s", "Weak Key Practice", targeted_desc)
  lines[#lines + 1] = targeted_line
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #targeted_line, "SplitTyperMenuDesc" }

  local dash_line = string.format("  [s]  %-28s %s", "Stats Dashboard", "View your typing profile")
  lines[#lines + 1] = dash_line
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #dash_line, "SplitTyperMenuDesc" }

  local combo_line = string.format("  [k]  %-28s %s", "Combo Trainer", "Practice Ctrl, Alt and modifier combos")
  lines[#lines + 1] = combo_line
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #combo_line, "SplitTyperMenuDesc" }
  lines[#lines + 1] = ""

  for _, section in ipairs(order) do
    local sep = " " .. string.rep("\u{2500}", 3) .. " " .. section .. " " .. string.rep("\u{2500}", 40 - #section)
    lines[#lines + 1] = sep
    highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
    lines[#lines + 1] = ""
    for _, cat in ipairs(groups[section]) do
      key_idx = key_idx + 1
      local key = key_pool[key_idx] or "?"
      cat_keys[cat.id] = key
      local line = string.format("  [%s]  %-28s %s", key, cat.name, cat.description)
      lines[#lines + 1] = line
      highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
      highlights[#highlights + 1] = { #lines - 1, 34, #line, "SplitTyperMenuDesc" }
    end
    lines[#lines + 1] = ""
  end

  local bottom_sep = string.rep("\u{2500}", 50)
  lines[#lines + 1] = bottom_sep
  highlights[#highlights + 1] = { #lines - 1, 0, #bottom_sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  [q] Quit"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Press a key to select a category"

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
  ctx.window.map(state, "c", ctx.actions.show_course)
  ctx.window.map(state, "s", ctx.actions.show_dashboard)
  ctx.window.map(state, "t", function()
    if ctx.errs.has_enough_data() then
      ctx.actions.start_targeted_exercise()
    end
  end)
  ctx.window.map(state, "k", ctx.actions.show_combo_menu)
  for _, cat in ipairs(cats) do
    local key = cat_keys[cat.id]
    if key then
      ctx.window.map(state, key, function()
        state.mode = "freeplay"
        ctx.actions.start_exercise(cat.id)
      end)
    end
  end
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<Esc>", ctx.actions.cleanup)
  ctx.window.map(state, "<C-c>", ctx.actions.cleanup)
end

function M.show_results(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.screen = "results"
  ctx.window.ensure_window(state, ctx.actions.cleanup)
  ctx.window.clear_buffer(state)

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
  add("       EXERCISE COMPLETE")
  hl(0, #lines[#lines], "SplitTyperTitle")
  add("")
  local sep = string.rep("\u{2500}", 44)
  add(sep)
  hl(0, #sep, "SplitTyperSep")
  add("")
  add(string.format("    WPM:         %d", stats.wpm))
  hl(17, #lines[#lines], stats.wpm >= 60 and "SplitTyperGood" or (stats.wpm >= 30 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Accuracy:    %.1f%%", stats.accuracy))
  hl(17, #lines[#lines], stats.accuracy >= 95 and "SplitTyperGood" or (stats.accuracy >= 80 and "SplitTyperOk" or "SplitTyperBad"))
  add(string.format("    Errors:      %d", stats.errors))
  hl(17, #lines[#lines], stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood")
  add(string.format("    Best streak: %d", stats.best_streak))
  hl(17, #lines[#lines], stats.best_streak >= stats.total_chars and "SplitTyperGood" or (stats.best_streak >= 20 and "SplitTyperOk" or "SplitTyperStats"))
  add(string.format("    Time:        %s", ctx.state_mod.format_time(stats.time)))
  add(string.format("    Characters:  %d", stats.total_chars))
  add("")
  add(string.format("    Score:       %d", stats.score))
  hl(17, #lines[#lines], "SplitTyperScore")
  add(string.format("    Rating:      %s", rating))
  hl(17, #lines[#lines], rating_hl)

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
    ctx.actions.start_exercise(state.category_id)
  end)
  ctx.window.map(state, "r", function()
    ctx.actions.start_exercise(state.category_id, state.exercise_idx)
  end)
  ctx.window.map(state, "m", ctx.actions.show_menu)
  ctx.window.map(state, "s", ctx.actions.show_dashboard)
  ctx.window.map(state, "q", ctx.actions.cleanup)
  ctx.window.map(state, "<Esc>", ctx.actions.show_menu)
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
    on_reset_errors = function()
      ctx.errs.reset()
      M.show_dashboard(ctx)
    end,
  })
end

return M
