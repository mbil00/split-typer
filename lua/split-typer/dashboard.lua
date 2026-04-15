local errors = require("split-typer.errors")
local storage = require("split-typer.storage")

local M = {}

-- Load history from disk
local function load_history()
  return storage.read_json(storage.data_path("history.json"), {})
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
          if info.value >= thresholds.good then
            hl = "SplitTyperGood"
          elseif info.value >= thresholds.ok then
            hl = "SplitTyperOk"
          else
            hl = "SplitTyperBad"
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
--- @param opts { on_back: function, on_quit: function, on_reset_errors: function }
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
  local total_time = 0
  local total_chars = 0
  local wpm_sum = 0
  local acc_sum = 0

  for _, h in ipairs(history) do
    total_time = total_time + (h.time or 0)
    total_chars = total_chars + (h.chars or 0)
    wpm_sum = wpm_sum + (h.wpm or 0)
    acc_sum = acc_sum + (h.accuracy or 0)
  end

  local avg_wpm = total_sessions > 0 and math.floor(wpm_sum / total_sessions) or 0
  local avg_acc = total_sessions > 0 and (math.floor(acc_sum / total_sessions * 10) / 10) or 0

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
  add(string.format("    Avg accuracy:  %.1f%%", avg_acc))
  local avg_acc_hl = avg_acc >= 95 and "SplitTyperGood" or (avg_acc >= 85 and "SplitTyperOk" or "SplitTyperBad")
  add_hl(19, #lines[#lines], avg_acc_hl)
  add("")

  -- WPM Trend
  local last_n = math.min(40, #history)
  if last_n > 0 then
    add_sep(string.format("WPM Trend (last %d sessions)", last_n))

    local wpm_values = {}
    for i = #history - last_n + 1, #history do
      wpm_values[#wpm_values + 1] = history[i].wpm or 0
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
    for i = #history - last_n + 1, #history do
      acc_values[#acc_values + 1] = history[i].accuracy or 0
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
  end

  -- Best scores per category
  if #history > 0 then
    add_sep("Best Scores")

    local best = {}
    for _, h in ipairs(history) do
      local cat = h.category or "?"
      if not best[cat] or (h.score or 0) > (best[cat].score or 0) then
        best[cat] = { category = cat, wpm = h.wpm, accuracy = h.accuracy, score = h.score }
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
      local line = string.format("    %-24s %3d WPM  %5.1f%%  score: %d", name, b.wpm or 0, b.accuracy or 0, b.score or 0)
      add(line)
      local score_hl = (b.score or 0) >= 400 and "SplitTyperGood" or ((b.score or 0) >= 100 and "SplitTyperOk" or "SplitTyperStats")
      add_hl(#line - #tostring(b.score or 0), #line, score_hl)
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
      local line = string.format("    '%s'  %5.1f%% error rate  (%d/%d)", wb.bigram, wb.error_rate * 100, wb.errors, wb.total)
      add(line)
      add_hl(4, 8, "SplitTyperBad")
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

  -- Keymaps
  local map = function(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  map("<Esc>", opts.on_back)
  map("q", opts.on_quit)
  map("<C-c>", opts.on_quit)
  map("R", function()
    opts.on_reset_errors()
  end)
end

-- Format a number with comma separators
function format_number(n)
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

return M
