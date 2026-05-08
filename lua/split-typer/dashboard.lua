local benchmarks = require("split-typer.benchmarks")
local errors = require("split-typer.errors")
local storage = require("split-typer.storage")

local M = {}

-- Load history from disk
local function load_history()
  return storage.read_json(storage.layout_data_path("history"), {})
end

local function format_number(n)
  local s = tostring(math.floor(n))
  local result = ""
  local len = #s
  for i = 1, len do
    if i > 1 and (len - i + 1) % 3 == 0 then
      result = result .. ","
    end
    result = result .. s:sub(i, i)
  end
  return result
end

local function get_timed_history(history)
  local timed = {}
  for _, item in ipairs(history) do
    if item.timed and item.timed_postmortem then
      timed[#timed + 1] = item
    end
  end
  return timed
end

local function is_typing_history_item(item)
  local mode = item.mode
  if mode == "typing" or mode == "timed" then
    return true
  end
  if mode == "combo" or mode == "reaction" then
    return false
  end
  -- Legacy entries written before the mode field existed: combo and reaction
  -- categories are always prefixed, so use the category to keep their
  -- CPM-magnitude speeds out of the WPM aggregates.
  local category = item.category or ""
  if category:match("^combo_") or category:match("^reaction_") then
    return false
  end
  return true
end

local function history_uncorrected_accuracy(item)
  return item.uncorrected_accuracy or item.accuracy or 0
end

local function history_corrected_accuracy(item)
  return item.corrected_accuracy or item.efficiency or item.accuracy or 0
end

local function history_backspaces_per_100(item)
  if item.backspaces_per_100_chars ~= nil then
    return item.backspaces_per_100_chars
  end
  local chars = item.chars or 0
  if chars > 0 then
    return ((item.backspaces or 0) / chars) * 100
  end
  return 0
end

local function history_hesitations_per_100(item)
  return item.hesitations_per_100_chars
end

local function history_category_profile(category_id)
  if not category_id or #category_id == 0 then
    return "other"
  end

  if category_id == "prose" then
    return "prose"
  end

  if category_id:match("^code_") or category_id == "mixed" then
    return "code"
  end

  if category_id:match("^course_")
    or category_id == "targeted_practice"
    or category_id == "transition_practice"
    or category_id == "course_transition_reinforcement"
  then
    return "drill"
  end

  local exercises = require("split-typer.exercises")
  local cat = exercises.get_category(category_id)
  if cat then
    if cat.group == "code_prose" then
      return cat.id == "prose" and "prose" or "code"
    end
    if cat.group == "advanced" then
      if cat.id == "advanced_prose_fluency" then
        return "prose"
      end
      if cat.id == "advanced_code_punctuation"
        or cat.id == "advanced_shell_cli"
        or cat.id == "advanced_delimiters"
      then
        return "code"
      end
      return "drill"
    end
    if cat.group == "general" or cat.group == "characters" or cat.group == "fingers" or cat.group == "custom" then
      return "drill"
    end
  end

  return "other"
end

local function average(values)
  if #values == 0 then
    return nil
  end
  local sum = 0
  for _, v in ipairs(values) do
    sum = sum + v
  end
  return sum / #values
end

local function average_pair(a, b)
  if a ~= nil and b ~= nil then
    return (a + b) / 2
  end
  return a or b
end

local function summarize_profile(history, profile)
  local items = {}
  for _, item in ipairs(history) do
    if history_category_profile(item.category) == profile then
      items[#items + 1] = item
    end
  end
  if #items == 0 then
    return nil
  end

  local wpm_values = {}
  local uncorrected_values = {}
  local corrected_values = {}
  local backspace_values = {}
  for _, item in ipairs(items) do
    wpm_values[#wpm_values + 1] = item.wpm or 0
    uncorrected_values[#uncorrected_values + 1] = history_uncorrected_accuracy(item)
    corrected_values[#corrected_values + 1] = history_corrected_accuracy(item)
    backspace_values[#backspace_values + 1] = history_backspaces_per_100(item)
  end

  return {
    count = #items,
    avg_wpm = average(wpm_values) or 0,
    avg_uncorrected = average(uncorrected_values) or 0,
    avg_corrected = average(corrected_values) or 0,
    avg_backspaces = average(backspace_values) or 0,
  }
end

-- Render an ASCII chart from a list of values.
-- Returns lines (strings) and highlights ({ line_offset, col_start, col_end, hl_group }).
local function render_chart(values, width, height, thresholds)
  -- thresholds: { good = N, ok = N } for coloring
  local lines = {}
  local highlights = {}

  if #values == 0 then
    lines[1] = "    (no data yet)"
    highlights[1] = { 0, 0, #lines[1], "SplitTyperPending" }
    return lines, highlights
  end

  local min_val = math.huge
  local max_val = -math.huge
  for _, v in ipairs(values) do
    if v < min_val then min_val = v end
    if v > max_val then max_val = v end
  end

  -- Add padding
  local range = max_val - min_val
  if range < 1 then
    range = 1
    min_val = min_val - 0.5
    max_val = max_val + 0.5
  end

  -- Label width for Y axis
  local label_w = math.max(#tostring(math.floor(max_val)), #tostring(math.floor(min_val))) + 1

  -- Chart area width
  local chart_w = width - label_w - 3 -- label + " | "
  if chart_w < 10 then chart_w = 10 end

  -- Map data points to chart columns
  -- If more data than columns, take the last chart_w points
  local plot_vals = values
  if #values > chart_w then
    plot_vals = {}
    for i = #values - chart_w + 1, #values do
      plot_vals[#plot_vals + 1] = values[i]
    end
  end

  -- Build the grid
  local grid = {}
  for row = 1, height do
    grid[row] = {}
    for col = 1, chart_w do
      grid[row][col] = " "
    end
  end

  -- Place data points
  local point_info = {} -- [col] = { row, value }
  for i, v in ipairs(plot_vals) do
    local col = i
    local row = height - math.floor((v - min_val) / range * (height - 1))
    if row < 1 then row = 1 end
    if row > height then row = height end
    grid[row][col] = "*"
    point_info[col] = { row = row, value = v }
  end

  -- Render rows
  for row = 1, height do
    -- Y axis label
    local y_val = max_val - (row - 1) / (height - 1) * range
    local label = string.format("%" .. label_w .. "d", math.floor(y_val))
    local row_chars = {}
    for col = 1, math.min(chart_w, #plot_vals) do
      row_chars[col] = grid[row][col]
    end
    -- Pad if fewer data points than width
    for col = #plot_vals + 1, chart_w do
      row_chars[col] = " "
    end
    local row_str = label .. " |" .. table.concat(row_chars)
    lines[#lines + 1] = row_str

    -- Highlight data points on this row
    local li = #lines - 1
    for col, info in pairs(point_info) do
      if info.row == row then
        local col_pos = label_w + 2 + col - 1 -- offset into the string
        local hl
        if thresholds then
          if thresholds.direction == "lower" then
            if info.value <= thresholds.good then
              hl = "SplitTyperGood"
            elseif info.value <= thresholds.ok then
              hl = "SplitTyperOk"
            else
              hl = "SplitTyperBad"
            end
          else
            if info.value >= thresholds.good then
              hl = "SplitTyperGood"
            elseif info.value >= thresholds.ok then
              hl = "SplitTyperOk"
            else
              hl = "SplitTyperBad"
            end
          end
        else
          hl = "SplitTyperProgress"
        end
        highlights[#highlights + 1] = { li, col_pos, col_pos + 1, hl }
      end
    end

    -- Dim the axis
    highlights[#highlights + 1] = { li, 0, label_w + 2, "SplitTyperSep" }
  end

  -- X axis line
  local x_axis = string.rep(" ", label_w) .. " " .. string.rep("\u{2500}", chart_w + 1)
  lines[#lines + 1] = x_axis
  highlights[#highlights + 1] = { #lines - 1, 0, #x_axis, "SplitTyperSep" }

  return lines, highlights
end

--- Render the dashboard into the given buffer.
--- @param buf number
--- @param ns number
--- @param win number
--- @param opts { on_back: function, on_quit: function, on_reset_errors: function, map: function }
function M.render(buf, ns, win, opts)
  local history = load_history()
  local err_summary = errors.get_summary()
  local win_width = vim.api.nvim_win_get_width(win)
  local chart_width = math.min(win_width - 6, 65)

  local lines = {}
  local highlights = {}

  local function add(text)
    lines[#lines + 1] = text or ""
  end

  local function add_hl(col_start, col_end, group)
    highlights[#highlights + 1] = { #lines - 1, col_start, col_end, group }
  end

  local function add_sep(title)
    local sep = " " .. string.rep("\u{2500}", 3) .. " " .. title .. " " .. string.rep("\u{2500}", math.max(1, chart_width - #title - 4))
    add(sep)
    add_hl(0, #sep, "SplitTyperSep")
    add("")
  end

  -- Header
  add("")
  add("       STATS DASHBOARD")
  add_hl(0, #lines[#lines], "SplitTyperTitle")
  add("")

  -- Overview
  add_sep("Overview")

  local total_sessions = #history
  local typing_history = {}
  local total_time = 0
  local total_chars = 0
  local wpm_sum = 0
  local uncorrected_acc_sum = 0
  local corrected_acc_sum = 0
  local backspace_rate_sum = 0
  local hesitation_rate_sum = 0
  local hesitation_rate_count = 0

  for _, h in ipairs(history) do
    total_time = total_time + (h.time or 0)
    total_chars = total_chars + (h.chars or 0)
    if is_typing_history_item(h) then
      typing_history[#typing_history + 1] = h
      wpm_sum = wpm_sum + (h.wpm or h.speed or 0)
      uncorrected_acc_sum = uncorrected_acc_sum + history_uncorrected_accuracy(h)
      corrected_acc_sum = corrected_acc_sum + history_corrected_accuracy(h)
      backspace_rate_sum = backspace_rate_sum + history_backspaces_per_100(h)
      if history_hesitations_per_100(h) ~= nil then
        hesitation_rate_sum = hesitation_rate_sum + history_hesitations_per_100(h)
        hesitation_rate_count = hesitation_rate_count + 1
      end
    end
  end

  local avg_wpm = #typing_history > 0 and math.floor(wpm_sum / #typing_history) or 0
  local avg_uncorrected_acc = #typing_history > 0 and (math.floor(uncorrected_acc_sum / #typing_history * 10) / 10) or 0
  local avg_corrected_acc = #typing_history > 0 and (math.floor(corrected_acc_sum / #typing_history * 10) / 10) or 0
  local avg_backspace_rate = #typing_history > 0 and (math.floor(backspace_rate_sum / #typing_history * 10) / 10) or 0
  local avg_hesitation_rate = hesitation_rate_count > 0 and (math.floor(hesitation_rate_sum / hesitation_rate_count * 10) / 10) or nil

  local hours = math.floor(total_time / 3600)
  local mins = math.floor((total_time % 3600) / 60)
  local time_str
  if hours > 0 then
    time_str = string.format("%dh %dm", hours, mins)
  else
    time_str = string.format("%dm", mins)
  end

  add(string.format("    Sessions:      %d", total_sessions))
  add(string.format("    Total time:    %s", time_str))
  add(string.format("    Characters:    %s", format_number(total_chars)))
  add(string.format("    Avg WPM:       %d", avg_wpm))
  local avg_wpm_hl = avg_wpm >= 50 and "SplitTyperGood" or (avg_wpm >= 25 and "SplitTyperOk" or "SplitTyperBad")
  add_hl(19, #lines[#lines], avg_wpm_hl)
  add(string.format("    Avg uncorrected acc: %.1f%%", avg_uncorrected_acc))
  local avg_uncorrected_hl = avg_uncorrected_acc >= 95 and "SplitTyperGood" or (avg_uncorrected_acc >= 85 and "SplitTyperOk" or "SplitTyperBad")
  add_hl(25, #lines[#lines], avg_uncorrected_hl)
  add(string.format("    Avg corrected acc:   %.1f%%", avg_corrected_acc))
  local avg_corrected_hl = avg_corrected_acc >= 95 and "SplitTyperGood" or (avg_corrected_acc >= 85 and "SplitTyperOk" or "SplitTyperBad")
  add_hl(25, #lines[#lines], avg_corrected_hl)
  add(string.format("    Avg backsp/100:      %.1f", avg_backspace_rate))
  local avg_backspace_hl = avg_backspace_rate <= 3 and "SplitTyperGood" or (avg_backspace_rate <= 8 and "SplitTyperOk" or "SplitTyperBad")
  add_hl(25, #lines[#lines], avg_backspace_hl)
  add(string.format("    Avg hesit/100:       %s", avg_hesitation_rate and string.format("%.1f", avg_hesitation_rate) or "n/a"))
  if avg_hesitation_rate ~= nil then
    local avg_hesitation_hl = avg_hesitation_rate <= 1 and "SplitTyperGood" or (avg_hesitation_rate <= 3 and "SplitTyperOk" or "SplitTyperBad")
    add_hl(25, #lines[#lines], avg_hesitation_hl)
  else
    add_hl(25, #lines[#lines], "SplitTyperPending")
  end
  add("")

  -- WPM Trend
  local last_n = math.min(40, #typing_history)
  if last_n > 0 then
    add_sep(string.format("WPM Trend (last %d sessions)", last_n))

    local wpm_values = {}
    for i = #typing_history - last_n + 1, #typing_history do
      wpm_values[#wpm_values + 1] = typing_history[i].wpm or typing_history[i].speed or 0
    end

    local chart_lines, chart_hls = render_chart(wpm_values, chart_width, 6, { good = 50, ok = 25 })
    local base = #lines
    for _, cl in ipairs(chart_lines) do
      add("    " .. cl)
    end
    for _, ch in ipairs(chart_hls) do
      highlights[#highlights + 1] = { base + ch[1], ch[2] + 4, ch[3] + 4, ch[4] }
    end
    add("")

    -- Accuracy Trend
    add_sep(string.format("Accuracy Trend (last %d sessions)", last_n))

    local acc_values = {}
    for i = #typing_history - last_n + 1, #typing_history do
      acc_values[#acc_values + 1] = history_uncorrected_accuracy(typing_history[i])
    end

    local acc_lines, acc_hls = render_chart(acc_values, chart_width, 6, { good = 95, ok = 85 })
    base = #lines
    for _, cl in ipairs(acc_lines) do
      add("    " .. cl)
    end
    for _, ch in ipairs(acc_hls) do
      highlights[#highlights + 1] = { base + ch[1], ch[2] + 4, ch[3] + 4, ch[4] }
    end
    add("")

    add_sep(string.format("Correction Dependence (last %d sessions)", last_n))

    local corrected_values = {}
    local backspace_values = {}
    local hesitation_values = {}
    for i = #typing_history - last_n + 1, #typing_history do
      corrected_values[#corrected_values + 1] = history_corrected_accuracy(typing_history[i])
      backspace_values[#backspace_values + 1] = history_backspaces_per_100(typing_history[i])
      if history_hesitations_per_100(typing_history[i]) ~= nil then
        hesitation_values[#hesitation_values + 1] = history_hesitations_per_100(typing_history[i])
      end
    end

    add(string.format(
      "    Recent corrected acc avg: %.1f%%    recent backsp/100 avg: %.1f",
      (#corrected_values > 0 and (function()
        local sum = 0
        for _, v in ipairs(corrected_values) do sum = sum + v end
        return math.floor((sum / #corrected_values) * 10) / 10
      end)() or 0),
      (#backspace_values > 0 and (function()
        local sum = 0
        for _, v in ipairs(backspace_values) do sum = sum + v end
        return math.floor((sum / #backspace_values) * 10) / 10
      end)() or 0)
    ))
    add_hl(31, #lines[#lines], "SplitTyperStats")

    local backspace_lines, backspace_hls = render_chart(backspace_values, chart_width, 6, { direction = "lower", good = 3, ok = 8 })
    base = #lines
    for _, cl in ipairs(backspace_lines) do
      add("    " .. cl)
    end
    for _, ch in ipairs(backspace_hls) do
      highlights[#highlights + 1] = { base + ch[1], ch[2] + 4, ch[3] + 4, ch[4] }
    end
    add("")

    if #hesitation_values > 0 then
      add_sep(string.format("Rhythm & Hesitation (last %d sessions)", #hesitation_values))
      add(string.format(
        "    Recent hesit/100 avg: %.1f",
        (function()
          local sum = 0
          for _, v in ipairs(hesitation_values) do sum = sum + v end
          return math.floor((sum / #hesitation_values) * 10) / 10
        end)()
      ))
      add_hl(28, #lines[#lines], "SplitTyperStats")

      local hesitation_lines, hesitation_hls = render_chart(hesitation_values, chart_width, 6, { direction = "lower", good = 1, ok = 3 })
      base = #lines
      for _, cl in ipairs(hesitation_lines) do
        add("    " .. cl)
      end
      for _, ch in ipairs(hesitation_hls) do
        highlights[#highlights + 1] = { base + ch[1], ch[2] + 4, ch[3] + 4, ch[4] }
      end
      add("")
    end
  end

  -- Best scores per category
  if #history > 0 then
    add_sep("Best Scores")

    local best = {}
    for _, h in ipairs(history) do
      local cat = h.category or "?"
      if not best[cat] or (h.score or 0) > (best[cat].score or 0) then
        best[cat] = {
          category = cat,
          wpm = h.wpm,
          cpm = h.cpm,
          speed = h.speed,
          speed_unit = h.speed_unit,
          accuracy = h.accuracy,
          score = h.score,
        }
      end
    end

    -- Sort by score descending
    local sorted = {}
    for _, b in pairs(best) do
      sorted[#sorted + 1] = b
    end
    table.sort(sorted, function(a, b)
      return (a.score or 0) > (b.score or 0)
    end)

    -- Resolve category names
    local exercises = require("split-typer.exercises")
    for i = 1, math.min(10, #sorted) do
      local b = sorted[i]
      local cat = exercises.get_category(b.category)
      local name = cat and cat.name or b.category
      local speed = b.speed or b.wpm or b.cpm or 0
      local unit = (b.speed_unit or (b.cpm and "cpm") or "wpm"):upper()
      local line = string.format("    %-24s %3d %s  %5.1f%%  score: %d", name, speed, unit, b.accuracy or 0, b.score or 0)
      add(line)
      local score_hl = (b.score or 0) >= 400 and "SplitTyperGood" or ((b.score or 0) >= 100 and "SplitTyperOk" or "SplitTyperStats")
      add_hl(#line - #tostring(b.score or 0), #line, score_hl)
    end
    add("")
  end

  if #history > 0 then
    add_sep("Transfer Quality")

    local prose = summarize_profile(history, "prose")
    local code = summarize_profile(history, "code")
    local drill = summarize_profile(history, "drill")

    if prose or code or drill then
      local function add_profile_line(label, summary)
        if not summary then
          add(string.format("    %-8s  (no sessions yet)", label))
          add_hl(0, #lines[#lines], "SplitTyperPending")
          return
        end
        local line = string.format(
          "    %-8s  %2d sessions  %3d WPM  %.1f%% uncorr  %.1f%% corr  %.1f backsp/100",
          label,
          summary.count,
          math.floor(summary.avg_wpm + 0.5),
          math.floor(summary.avg_uncorrected * 10) / 10,
          math.floor(summary.avg_corrected * 10) / 10,
          math.floor(summary.avg_backspaces * 10) / 10
        )
        add(line)
        local corr_hl = summary.avg_corrected >= 95 and "SplitTyperGood"
          or (summary.avg_corrected >= 85 and "SplitTyperOk" or "SplitTyperBad")
        add_hl(39, 53, corr_hl)
      end

      add_profile_line("Prose", prose)
      add_profile_line("Code", code)
      add_profile_line("Drill", drill)
      add("")

      if prose and code then
        local wpm_gap = math.floor((code.avg_wpm - prose.avg_wpm) + (code.avg_wpm >= prose.avg_wpm and 0.5 or -0.5))
        local corr_gap = math.floor((code.avg_corrected - prose.avg_corrected) * 10) / 10
        local line = string.format(
          "    Code vs prose gap: %+d WPM  %+0.1f corrected acc",
          wpm_gap,
          corr_gap
        )
        add(line)
        local gap_hl = "SplitTyperGood"
        if wpm_gap <= -8 or corr_gap <= -3 then
          gap_hl = "SplitTyperBad"
        elseif wpm_gap < 0 or corr_gap < 0 then
          gap_hl = "SplitTyperOk"
        end
        add_hl(24, #line, gap_hl)
      else
        add("    Need both prose and code sessions to measure real-text transfer.")
        add_hl(0, #lines[#lines], "SplitTyperPending")
      end

      if drill and (prose or code) then
        local real_text_wpm = average_pair(prose and prose.avg_wpm or nil, code and code.avg_wpm or nil)
        local real_text_corr = average_pair(prose and prose.avg_corrected or nil, code and code.avg_corrected or nil)
        if real_text_wpm and real_text_corr then
          local drill_gap_wpm = math.floor((drill.avg_wpm - real_text_wpm) + (drill.avg_wpm >= real_text_wpm and 0.5 or -0.5))
          local drill_gap_corr = math.floor((drill.avg_corrected - real_text_corr) * 10) / 10
          local line = string.format(
            "    Drill vs real-text gap: %+d WPM  %+0.1f corrected acc",
            drill_gap_wpm,
            drill_gap_corr
          )
          add(line)
          local gap_hl = "SplitTyperGood"
          if drill_gap_wpm >= 10 or drill_gap_corr >= 4 then
            gap_hl = "SplitTyperBad"
          elseif drill_gap_wpm > 4 or drill_gap_corr > 2 then
            gap_hl = "SplitTyperOk"
          end
          add_hl(28, #line, gap_hl)
        end
      else
        add("    Add a mix of drills and real text to see whether lesson gains are transferring.")
        add_hl(0, #lines[#lines], "SplitTyperPending")
      end
    else
      add("    Not enough history yet to compare drills against prose or code.")
      add_hl(0, #lines[#lines], "SplitTyperPending")
    end

    add("")
  end

  local benchmark_summary = benchmarks.get_summary()
  local have_benchmarks = false
  for _, item in ipairs(benchmark_summary) do
    if item.count > 0 then
      have_benchmarks = true
      break
    end
  end

  add_sep("Benchmarks")
  if have_benchmarks then
    for _, item in ipairs(benchmark_summary) do
      if item.count > 0 then
        local first = item.first
        local latest = item.latest
        local best = item.best
        local line = string.format(
          "    %-16s base %3d/%.1f  latest %3d/%.1f  best %3d/%.1f  (%d runs)",
          item.definition.name,
          first and (first.wpm or 0) or 0,
          first and (first.corrected_accuracy or first.efficiency or first.accuracy or 0) or 0,
          latest and (latest.wpm or 0) or 0,
          latest and (latest.corrected_accuracy or latest.efficiency or latest.accuracy or 0) or 0,
          best and (best.wpm or 0) or 0,
          best and (best.corrected_accuracy or best.efficiency or best.accuracy or 0) or 0,
          item.count
        )
        add(line)
        local latest_corr = latest and (latest.corrected_accuracy or latest.efficiency or latest.accuracy or 0) or 0
        local best_corr = best and (best.corrected_accuracy or best.efficiency or best.accuracy or 0) or 0
        add_hl(25, 35, latest_corr >= 95 and "SplitTyperGood" or (latest_corr >= 85 and "SplitTyperOk" or "SplitTyperBad"))
        add_hl(41, 49, best_corr >= 95 and "SplitTyperGood" or (best_corr >= 85 and "SplitTyperOk" or "SplitTyperBad"))
      end
    end
  else
    add("    No benchmark attempts yet. Run benchmarks from the main menu to establish baselines.")
    add_hl(0, #lines[#lines], "SplitTyperPending")
  end
  add("")

  local timed_history = get_timed_history(history)
  if #timed_history > 0 then
    add_sep("Timed Postmortem Trends")

    local count = 0
    local wpm_delta_sum = 0
    local acc_delta_sum = 0
    local eff_delta_sum = 0
    local collapse_count = 0
    local char_counts = {}
    local bigram_counts = {}

    for _, item in ipairs(timed_history) do
      local pm = item.timed_postmortem or {}
      local decay = pm.decay
      if decay then
        count = count + 1
        wpm_delta_sum = wpm_delta_sum + (decay.wpm_delta or 0)
        acc_delta_sum = acc_delta_sum + (decay.accuracy_delta or 0)
        eff_delta_sum = eff_delta_sum + (decay.efficiency_delta or 0)
        if (decay.wpm_delta or 0) <= -5 or (decay.accuracy_delta or 0) <= -3 or (decay.efficiency_delta or 0) <= -5 then
          collapse_count = collapse_count + 1
        end
      end

      for _, wc in ipairs(pm.worst_chars or {}) do
        char_counts[wc.char] = (char_counts[wc.char] or 0) + 1
      end
      for _, wb in ipairs(pm.worst_bigrams or {}) do
        bigram_counts[wb.bigram] = (bigram_counts[wb.bigram] or 0) + 1
      end
    end

    if count > 0 then
      local avg_wpm_delta = math.floor(wpm_delta_sum / count)
      local avg_acc_delta = math.floor((acc_delta_sum / count) * 10) / 10
      local avg_eff_delta = math.floor((eff_delta_sum / count) * 10) / 10
      local drift_line = string.format(
        "    Avg second-half drift: %+d WPM  %+0.1f acc  %+0.1f eff",
        avg_wpm_delta,
        avg_acc_delta,
        avg_eff_delta
      )
      add(drift_line)
      local drift_hl = "SplitTyperGood"
      if avg_wpm_delta <= -5 or avg_acc_delta <= -3 or avg_eff_delta <= -5 then
        drift_hl = "SplitTyperBad"
      elseif avg_wpm_delta < 0 or avg_acc_delta < 0 or avg_eff_delta < 0 then
        drift_hl = "SplitTyperOk"
      end
      add_hl(28, #drift_line, drift_hl)

      local collapse_rate = math.floor((collapse_count / count) * 100)
      local collapse_line = string.format("    Sessions with clear late-session drop: %d/%d (%d%%)", collapse_count, count, collapse_rate)
      add(collapse_line)
      add_hl(39, #collapse_line, collapse_rate >= 50 and "SplitTyperBad" or (collapse_rate >= 25 and "SplitTyperOk" or "SplitTyperGood"))
    else
      add("    Not enough timed-session decay data yet")
      add_hl(0, #lines[#lines], "SplitTyperPending")
    end

    local function sort_counts(map)
      local items = {}
      for key, n in pairs(map) do
        items[#items + 1] = { key = key, count = n }
      end
      table.sort(items, function(a, b)
        if a.count == b.count then
          return a.key < b.key
        end
        return a.count > b.count
      end)
      return items
    end

    local sorted_chars = sort_counts(char_counts)
    if #sorted_chars > 0 then
      add("    Most common timed weak keys:")
      add_hl(0, #lines[#lines], "SplitTyperSep")
      for i = 1, math.min(5, #sorted_chars) do
        local item = sorted_chars[i]
        local name = item.key == " " and "Space" or item.key
        local line = string.format("      '%s' appeared in %d timed postmortems", name, item.count)
        add(line)
        add_hl(6, 9, "SplitTyperBad")
      end
    end

    local sorted_bigrams = sort_counts(bigram_counts)
    if #sorted_bigrams > 0 then
      add("")
      add("    Most common timed weak bigrams:")
      add_hl(0, #lines[#lines], "SplitTyperSep")
      for i = 1, math.min(5, #sorted_bigrams) do
        local item = sorted_bigrams[i]
        local line = string.format("      %s appeared in %d timed postmortems", item.key, item.count)
        add(line)
        add_hl(6, 8, "SplitTyperBad")
      end
    end
    add("")
  end

  -- Problem keys
  add_sep("Weakest Keys")

  if err_summary.has_data and #err_summary.worst_chars > 0 then
    for i = 1, math.min(6, #err_summary.worst_chars) do
      local wc = err_summary.worst_chars[i]
      -- Build confused_with list
      local subs = {}
      for actual, cnt in pairs(wc.confused_with) do
        subs[#subs + 1] = { ch = actual, cnt = cnt }
      end
      table.sort(subs, function(a, b)
        return a.cnt > b.cnt
      end)
      local sub_str = ""
      if #subs > 0 then
        local parts = {}
        for j = 1, math.min(3, #subs) do
          parts[#parts + 1] = subs[j].ch
        end
        sub_str = "  often typed as: " .. table.concat(parts, ", ")
      end

      local line = string.format("    '%s'  %5.1f%% error rate  (%d/%d)%s", wc.char, wc.error_rate * 100, wc.errors, wc.total, sub_str)
      add(line)
      local rate_hl = wc.error_rate >= 0.2 and "SplitTyperBad" or (wc.error_rate >= 0.1 and "SplitTyperOk" or "SplitTyperStats")
      add_hl(4, 7, "SplitTyperBad")
      add_hl(9, 20, rate_hl)
    end
  else
    add("    (not enough data yet - keep practicing!)")
    add_hl(0, #lines[#lines], "SplitTyperPending")
  end
  add("")

  -- Hardest transitions
  if err_summary.has_data and #err_summary.worst_bigrams > 0 then
    add_sep("Hardest Transitions")

    for i = 1, math.min(5, #err_summary.worst_bigrams) do
      local wb = err_summary.worst_bigrams[i]
      local class_note = ""
      if wb.class_names and #wb.class_names > 0 then
        class_note = "  " .. table.concat(wb.class_names, ", ")
      end
      local line = string.format("    '%s'  %5.1f%% error rate  (%d/%d)%s", wb.bigram, wb.error_rate * 100, wb.errors, wb.total, class_note)
      add(line)
      add_hl(4, 8, "SplitTyperBad")
    end
    add("")
  end

  if err_summary.has_data and #err_summary.worst_transition_classes > 0 then
    add_sep("Weak Movement Types")

    for i = 1, math.min(5, #err_summary.worst_transition_classes) do
      local wc = err_summary.worst_transition_classes[i]
      local line = string.format(
        "    %s  %5.1f%% error rate  (%d/%d)  sample: '%s'",
        wc.name,
        wc.error_rate * 100,
        wc.errors,
        wc.total,
        wc.sample
      )
      add(line)
      add_hl(4, 4 + #wc.name, "SplitTyperBad")
    end
    add("    Raw severity only. A transition can belong to multiple movement types, so these rates are not additive.")
    add_hl(0, #lines[#lines], "SplitTyperPending")
    add("")

    local adaptive = errors.get_worst_transition_classes(5, 10, { weighted = true })
    if #adaptive > 0 then
      add("    Auto-focus priority:")
      add_hl(0, #lines[#lines], "SplitTyperSep")
      for i = 1, math.min(5, #adaptive) do
        local wc = adaptive[i]
        local line = string.format(
          "      %s  score %.3f  evidence %.2f  %d patterns  sample: '%s'",
          wc.name,
          wc.auto_score or 0,
          wc.evidence_score or 0,
          wc.distinct_examples or 0,
          wc.sample
        )
        add(line)
        add_hl(6, 6 + #wc.name, i == 1 and "SplitTyperGood" or "SplitTyperOk")
      end
      add("    Auto focus uses class weights and evidence quality, so this order can differ from raw error rate.")
      add_hl(0, #lines[#lines], "SplitTyperPending")
      add("")
    end
  end

  if err_summary.has_data and #err_summary.worst_trigrams > 0 then
    add_sep("Transition Chains")

    for i = 1, math.min(4, #err_summary.worst_trigrams) do
      local wt = err_summary.worst_trigrams[i]
      local line = string.format("    '%s'  %5.1f%% error rate  (%d/%d)", wt.trigram, wt.error_rate * 100, wt.errors, wt.total)
      add(line)
      add_hl(4, 9, "SplitTyperBad")
    end
    add("")
  end

  -- Activity
  add_sep("Activity")

  if #history > 0 then
    -- Today / This week
    local today = os.date("%Y-%m-%d")
    local today_sessions = 0
    local today_time = 0
    local week_sessions = 0
    local week_time = 0
    local today_ts = os.time()

    for _, h in ipairs(history) do
      local date = (h.date or ""):sub(1, 10)
      if date == today then
        today_sessions = today_sessions + 1
        today_time = today_time + (h.time or 0)
      end
      -- Simple week check: within last 7 days by string comparison
      -- (good enough for display purposes)
      if date >= os.date("%Y-%m-%d", today_ts - 7 * 86400) then
        week_sessions = week_sessions + 1
        week_time = week_time + (h.time or 0)
      end
    end

    -- Practice streak (consecutive days)
    local days_seen = {}
    for _, h in ipairs(history) do
      local date = (h.date or ""):sub(1, 10)
      if date ~= "" then
        days_seen[date] = true
      end
    end
    local streak = 0
    local check_ts = today_ts
    while true do
      local check_date = os.date("%Y-%m-%d", check_ts)
      if days_seen[check_date] then
        streak = streak + 1
        check_ts = check_ts - 86400
      else
        break
      end
    end

    local fmt_time = function(secs)
      local h = math.floor(secs / 3600)
      local m = math.floor((secs % 3600) / 60)
      if h > 0 then return string.format("%dh %dm", h, m) end
      return string.format("%dm", m)
    end

    add(string.format("    Today:       %d sessions, %s", today_sessions, fmt_time(today_time)))
    add(string.format("    This week:   %d sessions, %s", week_sessions, fmt_time(week_time)))
    add(string.format("    Streak:      %d day%s", streak, streak == 1 and "" or "s"))
    local streak_hl = streak >= 7 and "SplitTyperGood" or (streak >= 3 and "SplitTyperOk" or "SplitTyperStats")
    add_hl(17, #lines[#lines], streak_hl)
  else
    add("    No sessions recorded yet")
    add_hl(0, #lines[#lines], "SplitTyperPending")
  end
  add("")

  -- Navigation
  local nav_sep = string.rep("\u{2500}", chart_width + 4)
  add(nav_sep)
  add_hl(0, #nav_sep, "SplitTyperSep")
  add("")
  add("  [Esc] Back to menu    [q] Quit    [R] Reset error data")
  add_hl(2, 7, "SplitTyperMenuKey")
  add_hl(24, 27, "SplitTyperMenuKey")
  add_hl(36, 39, "SplitTyperMenuKey")

  -- Write to buffer
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(highlights) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
    })
  end

  opts.map("<Esc>", opts.on_back)
  opts.map("q", opts.on_quit)
  opts.map("<C-c>", opts.on_quit)
  opts.map("R", function()
    opts.on_reset_errors()
  end)
end

return M
