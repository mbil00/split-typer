local words = require("split-typer.words")

local M = {}

-- Persistence
local data_dir = vim.fn.stdpath("data") .. "/split-typer"
local errors_file = data_dir .. "/errors.json"

local _data = nil

--- Load error data from disk.
local function load_data()
  if _data then
    return _data
  end

  local f = io.open(errors_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
      local ok, parsed = pcall(vim.json.decode, content)
      if ok and type(parsed) == "table" then
        _data = parsed
        return _data
      end
    end
  end

  _data = {
    chars = {},
    bigrams = {},
    total_chars = 0,
    total_errors = 0,
    last_updated = "",
  }
  return _data
end

--- Save error data to disk.
local function save_data()
  if not _data then
    return
  end
  vim.fn.mkdir(data_dir, "p")
  local f = io.open(errors_file, "w")
  if f then
    f:write(vim.json.encode(_data))
    f:close()
  end
end

--- Record errors from a completed exercise session.
--- @param error_log { expected: string, actual: string, pos: number }[]
--- @param char_map { char: string, is_newline: boolean }[]
function M.record_session(error_log, char_map)
  local data = load_data()

  -- Build a set of positions that had errors for bigram tracking
  local error_positions = {}
  for _, e in ipairs(error_log) do
    error_positions[e.pos] = e
  end

  -- Update per-character totals
  for i = 1, #char_map do
    local entry = char_map[i]
    if entry.is_newline then
      goto continue_char
    end

    local ch = entry.char
    if not data.chars[ch] then
      data.chars[ch] = { total = 0, errors = 0, confused_with = {} }
    end
    data.chars[ch].total = data.chars[ch].total + 1
    data.total_chars = data.total_chars + 1

    local err = error_positions[i]
    if err then
      data.chars[ch].errors = data.chars[ch].errors + 1
      data.total_errors = data.total_errors + 1
      local cw = data.chars[ch].confused_with
      cw[err.actual] = (cw[err.actual] or 0) + 1
    end

    ::continue_char::
  end

  -- Update bigram totals
  local prev_ch = nil
  local prev_pos = nil
  for i = 1, #char_map do
    local entry = char_map[i]
    if entry.is_newline then
      prev_ch = nil
      prev_pos = nil
      goto continue_bi
    end

    if prev_ch then
      local bigram = prev_ch .. entry.char
      if not data.bigrams[bigram] then
        data.bigrams[bigram] = { total = 0, errors = 0 }
      end
      data.bigrams[bigram].total = data.bigrams[bigram].total + 1
      -- Count bigram as error if either position had an error
      if error_positions[prev_pos] or error_positions[i] then
        data.bigrams[bigram].errors = data.bigrams[bigram].errors + 1
      end
    end

    prev_ch = entry.char
    prev_pos = i

    ::continue_bi::
  end

  data.last_updated = os.date("%Y-%m-%d %H:%M:%S")
  save_data()
end

--- Get the N worst characters by error rate.
--- @param n number How many to return
--- @param min_total? number Minimum attempts before a char qualifies (default 20)
--- @return { char: string, error_rate: number, total: number, errors: number, confused_with: table }[]
function M.get_worst_chars(n, min_total)
  min_total = min_total or 20
  local data = load_data()
  local results = {}

  for ch, info in pairs(data.chars) do
    if info.total >= min_total and info.errors > 0 then
      results[#results + 1] = {
        char = ch,
        error_rate = info.errors / info.total,
        total = info.total,
        errors = info.errors,
        confused_with = info.confused_with or {},
      }
    end
  end

  table.sort(results, function(a, b)
    return a.error_rate > b.error_rate
  end)

  local out = {}
  for i = 1, math.min(n, #results) do
    out[i] = results[i]
  end
  return out
end

--- Get the N worst bigrams by error rate.
--- @param n number
--- @param min_total? number (default 10)
--- @return { bigram: string, error_rate: number, total: number, errors: number }[]
function M.get_worst_bigrams(n, min_total)
  min_total = min_total or 10
  local data = load_data()
  local results = {}

  for bi, info in pairs(data.bigrams) do
    if info.total >= min_total and info.errors > 0 then
      results[#results + 1] = {
        bigram = bi,
        error_rate = info.errors / info.total,
        total = info.total,
        errors = info.errors,
      }
    end
  end

  table.sort(results, function(a, b)
    return a.error_rate > b.error_rate
  end)

  local out = {}
  for i = 1, math.min(n, #results) do
    out[i] = results[i]
  end
  return out
end

--- Get a summary for display.
--- @return { worst_chars: table, worst_bigrams: table, total_chars: number, total_errors: number, has_data: boolean }
function M.get_summary()
  local data = load_data()
  return {
    worst_chars = M.get_worst_chars(8),
    worst_bigrams = M.get_worst_bigrams(6),
    total_chars = data.total_chars,
    total_errors = data.total_errors,
    has_data = data.total_chars >= 50,
  }
end

--- Format session errors for display on results screen.
--- @param error_log { expected: string, actual: string, pos: number }[]
--- @return string[] lines
--- @return { [1]: number, [2]: number, [3]: number, [4]: string }[] highlights
function M.format_session_errors(error_log)
  local lines = {}
  local highlights = {}

  if #error_log == 0 then
    lines[1] = "    No errors - perfect!"
    highlights[1] = { 0, 0, #lines[1], "SplitTyperGood" }
    return lines, highlights
  end

  -- Tally errors by expected char
  local by_char = {}
  for _, e in ipairs(error_log) do
    local ch = e.expected
    if not by_char[ch] then
      by_char[ch] = { count = 0, typed_as = {} }
    end
    by_char[ch].count = by_char[ch].count + 1
    by_char[ch].typed_as[e.actual] = (by_char[ch].typed_as[e.actual] or 0) + 1
  end

  -- Sort by error count descending
  local sorted = {}
  for ch, info in pairs(by_char) do
    sorted[#sorted + 1] = { char = ch, count = info.count, typed_as = info.typed_as }
  end
  table.sort(sorted, function(a, b)
    return a.count > b.count
  end)

  -- Format top 5
  local shown = math.min(5, #sorted)
  for i = 1, shown do
    local e = sorted[i]
    -- Build "typed as" list
    local subs = {}
    for actual, cnt in pairs(e.typed_as) do
      local display = actual
      if actual == " " then
        display = "Space"
      elseif actual == "\n" then
        display = "Enter"
      end
      subs[#subs + 1] = { actual = display, count = cnt }
    end
    table.sort(subs, function(a, b)
      return a.count > b.count
    end)
    local sub_parts = {}
    for j = 1, math.min(3, #subs) do
      sub_parts[#sub_parts + 1] = string.format("'%s'", subs[j].actual)
    end

    local display_char = e.char
    if display_char == " " then
      display_char = "Space"
    end

    local line = string.format("      '%s' mistyped %dx (typed as: %s)", display_char, e.count, table.concat(sub_parts, ", "))
    lines[#lines + 1] = line
    highlights[#highlights + 1] = { #lines - 1, 6, 9, "SplitTyperBad" }
  end

  -- Show all-time worst keys if we have data
  local summary = M.get_summary()
  if summary.has_data and #summary.worst_chars > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "    Weakest keys (all time):"
    highlights[#highlights + 1] = { #lines - 1, 0, #lines[#lines], "SplitTyperSep" }

    for i = 1, math.min(3, #summary.worst_chars) do
      local wc = summary.worst_chars[i]
      local line = string.format("      '%s'  %.0f%% error rate  (%d/%d)", wc.char, wc.error_rate * 100, wc.errors, wc.total)
      lines[#lines + 1] = line
      highlights[#highlights + 1] = { #lines - 1, 6, 9, "SplitTyperBad" }
    end
  end

  return lines, highlights
end

--- Generate a targeted exercise focusing on the user's weakest characters.
--- @param opts? { min_words?: number, max_words?: number }
--- @return string exercise_text
--- @return string description
function M.generate_targeted_exercise(opts)
  opts = opts or {}
  local worst = M.get_worst_chars(5, 15)

  if #worst == 0 then
    -- Not enough data, fall back to general exercise
    return words.generate({
      chars = "abcdefghijklmnopqrstuvwxyz",
      min_words = opts.min_words or 12,
      max_words = opts.max_words or 20,
    }), "General practice (not enough error data yet)"
  end

  -- Build focus chars from worst characters
  local focus = {}
  for _, wc in ipairs(worst) do
    focus[#focus + 1] = wc.char
  end
  local focus_str = table.concat(focus)

  local text = words.generate({
    chars = "abcdefghijklmnopqrstuvwxyz",
    focus_chars = focus_str,
    min_focus_density = 0.25,
    min_words = opts.min_words or 12,
    max_words = opts.max_words or 20,
  })

  local desc_parts = {}
  for i = 1, math.min(3, #worst) do
    desc_parts[#desc_parts + 1] = string.format("'%s' (%.0f%%)", worst[i].char, worst[i].error_rate * 100)
  end

  return text, "Targeting: " .. table.concat(desc_parts, ", ")
end

--- Check if there is enough data for targeted exercises.
--- @return boolean
function M.has_enough_data()
  local data = load_data()
  return data.total_chars >= 100
end

--- Reset all error data.
function M.reset()
  _data = {
    chars = {},
    bigrams = {},
    total_chars = 0,
    total_errors = 0,
    last_updated = "",
  }
  save_data()
end

return M
