local storage = require("split-typer.storage")
local words = require("split-typer.words")

local M = {}

-- Persistence
local errors_file = storage.data_path("errors.json")

local _data = nil

local function warn_save_failure(kind)
  vim.schedule(function()
    vim.notify("split-typer: failed to save " .. kind, vim.log.levels.WARN)
  end)
end

--- Load error data from disk.
local function load_data()
  if _data then
    return _data
  end

  _data = storage.read_json(errors_file, {
    chars = {},
    bigrams = {},
    total_chars = 0,
    total_errors = 0,
    last_updated = "",
  })
  return _data
end

--- Save error data to disk.
local function save_data()
  if not _data then
    return
  end
  if not storage.write_json(errors_file, _data) then
    warn_save_failure("error statistics")
  end
end

local function make_set(chars)
  local set = {}
  for i = 1, #chars do
    set[chars:sub(i, i)] = true
  end
  return set
end

local function append_unique_chars(out, seen, chars, allowed)
  for i = 1, #chars do
    local ch = chars:sub(i, i)
    if not seen[ch] and (not allowed or allowed[ch]) then
      seen[ch] = true
      out[#out + 1] = ch
    end
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

local function build_error_positions(error_log)
  local positions = {}
  for _, err in ipairs(error_log) do
    positions[err.pos] = true
  end
  return positions
end

--- Get worst characters for a single session.
--- @param error_log { expected: string, actual: string, pos: number }[]
--- @param n? number
--- @return { char: string, count: number, typed_as: table }[]
function M.get_session_worst_chars(error_log, n)
  local tally = {}
  for _, err in ipairs(error_log) do
    local item = tally[err.expected]
    if not item then
      item = { char = err.expected, count = 0, typed_as = {} }
      tally[err.expected] = item
    end
    item.count = item.count + 1
    item.typed_as[err.actual] = (item.typed_as[err.actual] or 0) + 1
  end

  local items = {}
  for _, item in pairs(tally) do
    items[#items + 1] = item
  end
  table.sort(items, function(a, b)
    return a.count > b.count
  end)

  local out = {}
  for i = 1, math.min(n or 5, #items) do
    out[#out + 1] = items[i]
  end
  return out
end

--- Get worst bigrams for a single session.
--- @param error_log { expected: string, actual: string, pos: number }[]
--- @param char_map { char: string, is_newline: boolean }[]
--- @param n? number
--- @param max_pos? number
--- @return { bigram: string, total: number, errors: number, error_rate: number }[]
function M.get_session_worst_bigrams(error_log, char_map, n, max_pos)
  if not char_map then
    return {}
  end

  local error_positions = build_error_positions(error_log)
  local tally = {}
  local prev_char = nil
  local prev_pos = nil
  local limit = math.min(max_pos or #char_map, #char_map)
  for i = 1, limit do
    local entry = char_map[i]
    if entry.is_newline then
      prev_char = nil
      prev_pos = nil
      goto continue
    end

    if prev_char then
      local bigram = prev_char .. entry.char
      local item = tally[bigram]
      if not item then
        item = { bigram = bigram, total = 0, errors = 0, error_rate = 0 }
        tally[bigram] = item
      end
      item.total = item.total + 1
      if error_positions[prev_pos] or error_positions[i] then
        item.errors = item.errors + 1
      end
    end

    prev_char = entry.char
    prev_pos = i
    ::continue::
  end

  local items = {}
  for _, item in pairs(tally) do
    if item.errors > 0 then
      item.error_rate = item.errors / item.total
      items[#items + 1] = item
    end
  end
  table.sort(items, function(a, b)
    if a.error_rate == b.error_rate then
      return a.errors > b.errors
    end
    return a.error_rate > b.error_rate
  end)

  local out = {}
  for i = 1, math.min(n or 5, #items) do
    out[#out + 1] = items[i]
  end
  return out
end

--- Summarize first-half vs second-half session performance.
--- @param key_events { t: number, kind: string, correct?: boolean }[]
--- @return table|nil
function M.get_session_decay(key_events)
  if not key_events or #key_events < 2 then
    return nil
  end

  local start_t = key_events[1].t
  local end_t = key_events[#key_events].t
  if not start_t or not end_t or end_t <= start_t then
    return nil
  end
  local midpoint = start_t + ((end_t - start_t) / 2)

  local function summarize(bucket)
    local typed = 0
    local correct = 0
    local mistakes = 0
    local backspaces = 0
    local first_t = nil
    local last_t = nil

    for _, event in ipairs(bucket) do
      first_t = first_t or event.t
      last_t = event.t
      if event.kind == "type" then
        typed = typed + 1
        if event.correct then
          correct = correct + 1
        else
          mistakes = mistakes + 1
        end
      elseif event.kind == "backspace" then
        backspaces = backspaces + 1
      end
    end

    local elapsed = 0
    if first_t and last_t and last_t > first_t then
      elapsed = (last_t - first_t) / 1e9
    end
    local accuracy = (correct + mistakes) > 0 and (correct / (correct + mistakes) * 100) or 100
    local efficiency = (typed + backspaces) > 0 and (correct / (typed + backspaces) * 100) or 100
    local wpm = elapsed > 0 and ((correct / 5) / (elapsed / 60)) or 0

    return {
      typed = typed,
      correct = correct,
      mistakes = mistakes,
      backspaces = backspaces,
      accuracy = accuracy,
      efficiency = efficiency,
      wpm = wpm,
    }
  end

  local first_half = {}
  local second_half = {}
  for _, event in ipairs(key_events) do
    if event.t <= midpoint then
      first_half[#first_half + 1] = event
    else
      second_half[#second_half + 1] = event
    end
  end

  if #first_half == 0 or #second_half == 0 then
    return nil
  end

  local first = summarize(first_half)
  local second = summarize(second_half)
  return {
    first = first,
    second = second,
    wpm_delta = second.wpm - first.wpm,
    accuracy_delta = second.accuracy - first.accuracy,
    efficiency_delta = second.efficiency - first.efficiency,
  }
end

--- Build an adaptive focus-char string from seed chars and the user's weak keys.
--- @param opts? { allowed_chars?: string, seed_chars?: string, limit?: number, min_total?: number }
--- @return string
function M.get_adaptive_focus_chars(opts)
  opts = opts or {}
  local allowed = opts.allowed_chars and make_set(opts.allowed_chars) or nil
  local out = {}
  local seen = {}

  append_unique_chars(out, seen, opts.seed_chars or "", allowed)

  local worst = M.get_worst_chars(opts.limit or 6, opts.min_total or 15)
  for _, wc in ipairs(worst) do
    append_unique_chars(out, seen, wc.char, allowed)
    local confused = {}
    for actual, count in pairs(wc.confused_with or {}) do
      confused[#confused + 1] = { actual = actual, count = count }
    end
    table.sort(confused, function(a, b)
      return a.count > b.count
    end)
    for i = 1, math.min(2, #confused) do
      append_unique_chars(out, seen, confused[i].actual, allowed)
    end
  end

  return table.concat(out)
end

--- Generate a targeted exercise focusing on the user's weakest characters.
--- @param opts? { min_words?: number, max_words?: number, allowed_chars?: string, seed_chars?: string, min_focus_occurrences?: number }
--- @return string exercise_text
--- @return string description
function M.generate_targeted_exercise(opts)
  opts = opts or {}
  local worst = M.get_worst_chars(5, 15)
  local allowed_chars = opts.allowed_chars or "abcdefghijklmnopqrstuvwxyz"
  local adaptive_focus = M.get_adaptive_focus_chars({
    allowed_chars = allowed_chars,
    seed_chars = opts.seed_chars or "",
    limit = 6,
    min_total = 15,
  })

  if #worst == 0 then
    -- Not enough data, fall back to general exercise
    return words.generate({
      chars = allowed_chars,
      min_words = opts.min_words or 12,
      max_words = opts.max_words or 20,
    }), "General practice (not enough error data yet)"
  end

  local text = words.generate({
    chars = allowed_chars,
    focus_chars = adaptive_focus,
    min_focus_density = 0.25,
    min_focus_occurrences = opts.min_focus_occurrences or math.max(10, #adaptive_focus * 3),
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
