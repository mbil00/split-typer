local storage = require("split-typer.storage")
local words = require("split-typer.words")

local M = {}

-- Persistence
local errors_file = storage.layout_data_path("errors")

local _data = nil

local function warn_save_failure(kind)
  vim.schedule(function()
    vim.notify("split-typer: failed to save " .. kind, vim.log.levels.WARN)
  end)
end

-- Cap `examples` maps on transition classes so errors.json does not grow without bound.
local CLASS_EXAMPLES_CAP = 48
local CLASS_EXAMPLES_KEEP = 24

local function prune_class_examples(examples)
  local items = {}
  for bigram, count in pairs(examples) do
    items[#items + 1] = { bigram = bigram, count = count }
  end
  if #items <= CLASS_EXAMPLES_CAP then
    return examples, #items
  end
  table.sort(items, function(a, b) return a.count > b.count end)
  local out = {}
  for i = 1, math.min(CLASS_EXAMPLES_KEEP, #items) do
    out[items[i].bigram] = items[i].count
  end
  return out, CLASS_EXAMPLES_KEEP
end

--- Load error data from disk.
local function load_data()
  if _data then
    return _data
  end

  _data = storage.read_json(errors_file, {
    chars = {},
    bigrams = {},
    trigrams = {},
    transition_classes = {},
    total_chars = 0,
    total_errors = 0,
    last_updated = "",
  })
  _data.chars = _data.chars or {}
  _data.bigrams = _data.bigrams or {}
  _data.trigrams = _data.trigrams or {}
  _data.transition_classes = _data.transition_classes or {}
  _data.total_chars = _data.total_chars or 0
  _data.total_errors = _data.total_errors or 0
  _data.last_updated = _data.last_updated or ""
  for _, class_info in pairs(_data.transition_classes) do
    if class_info.examples then
      class_info.examples = prune_class_examples(class_info.examples)
    end
  end
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

local layouts = require("split-typer.layouts")

-- char_meta, shifted_number_symbols, and exact_cross_center_pairs are owned by
-- the layouts module and mutated in place on layout change, so these local
-- references stay valid across setup({ layout }) calls.
local char_meta = layouts.char_meta
local shifted_number_symbols = layouts.shifted_number_symbols
local exact_cross_center_pairs = layouts.cross_center_pairs

local function get_char_meta(ch)
  return char_meta[ch]
end

local function is_whitespace(ch)
  return ch == " " or ch == "\n" or ch == "\t"
end

local function classify_transition(a, b)
  local labels = {}
  local a_meta = get_char_meta(a)
  local b_meta = get_char_meta(b)
  local a_is_space = is_whitespace(a)
  local b_is_space = is_whitespace(b)
  local a_is_symbol = (not a_is_space) and (not a:match("[%w]"))
  local b_is_symbol = (not b_is_space) and (not b:match("[%w]"))
  local a_is_digit = a:match("%d") ~= nil or shifted_number_symbols[a] or false
  local b_is_digit = b:match("%d") ~= nil or shifted_number_symbols[b] or false

  if a_is_symbol or b_is_symbol then
    labels[#labels + 1] = "symbol_jump"
  end
  if a_is_digit or b_is_digit then
    labels[#labels + 1] = "number_row"
  end

  if a_meta and b_meta then
    local involves_thumb = a_meta.finger == "thumb" or b_meta.finger == "thumb"
    if involves_thumb then
      labels[#labels + 1] = "thumb_cluster"
    else
      if a_meta.hand == b_meta.hand then
        labels[#labels + 1] = "same_hand"
      else
        labels[#labels + 1] = "cross_hand"
      end

      if a_meta.finger == b_meta.finger then
        labels[#labels + 1] = "same_finger"
      end
    end

    local pair = a:lower() .. b:lower()
    if exact_cross_center_pairs[pair] then
      labels[#labels + 1] = "cross_center"
    end
  else
    labels[#labels + 1] = "unclassified"
  end

  if #labels == 0 then
    labels[1] = "unclassified"
  end
  return labels, a_meta, b_meta
end

local class_display_names = {
  same_hand = "Same Hand",
  cross_hand = "Hand Alternation",
  same_finger = "Same Finger",
  cross_center = "Cross Center",
  symbol_jump = "Symbol Jump",
  number_row = "Number Row",
  thumb_cluster = "Thumb Cluster",
  unclassified = "Mixed / Unclassified",
}

local class_descriptions = {
  same_hand = "Keep one hand moving cleanly through same-side transitions",
  cross_hand = "Improve left-right alternation and rhythm between hands",
  same_finger = "Reduce repeated-finger collisions and finger reuse errors",
  cross_center = "Clean up crossings around T G B and Y H N",
  symbol_jump = "Stabilize punctuation and symbol transitions",
  number_row = "Build confidence on digits and shifted number-row reaches",
  thumb_cluster = "Train space, enter, and thumb-driven transitions",
  unclassified = "Catch mixed patterns that do not fit the main buckets",
}

local class_order = {
  "same_finger",
  "cross_center",
  "cross_hand",
  "same_hand",
  "symbol_jump",
  "number_row",
  "thumb_cluster",
  "unclassified",
}

local class_generation_profiles = {
  same_finger = {
    style = "same_finger",
    combo_ratio = 0.45,
    plain_ratio = 0.2,
    curated_ratio = 0.35,
    min_words = 14,
    max_words = 20,
    curated_templates = {
      "{transition} {transition}{transition} {a}{b}{a}{b}",
      "{a}{transition}{a} {b}{transition}{b}",
      "{transition} {a}{a}{b} {transition}",
    },
  },
  cross_center = {
    style = "cross_center",
    combo_ratio = 0.35,
    plain_ratio = 0.28,
    curated_ratio = 0.3,
    min_words = 14,
    max_words = 20,
    allowed_chars = "abcdefghijklmnopqrstuvwxyz",
    curated_templates = {
      "{transition} gather {transition} rhythm",
      "energy {transition} beyond {transition}",
      "{a}{transition}{b} theory {transition}",
    },
  },
  cross_hand = {
    style = "cross_hand",
    combo_ratio = 0.28,
    plain_ratio = 0.4,
    curated_ratio = 0.24,
    min_words = 16,
    max_words = 24,
    allowed_chars = "abcdefghijklmnopqrstuvwxyz",
    curated_templates = {
      "{transition} rapid {transition} rhythm",
      "balance {transition} motion {transition}",
      "{a}{b}{a}{b} steady {transition}",
    },
  },
  same_hand = {
    style = "same_hand",
    combo_ratio = 0.3,
    plain_ratio = 0.3,
    curated_ratio = 0.24,
    min_words = 14,
    max_words = 20,
    allowed_chars = "abcdefghijklmnopqrstuvwxyz",
    curated_templates = {
      "{transition} smooth {transition} control",
      "{a}{transition} settle {transition}",
      "steady {transition} sequence {transition}",
    },
  },
  symbol_jump = {
    style = "symbol_jump",
    combo_ratio = 0.55,
    plain_ratio = 0.15,
    curated_ratio = 0.48,
    min_words = 12,
    max_words = 18,
    curated_templates = {
      "({transition}) [{transition}]",
      "fn({a}) => {transition};",
      "arr[{a}] {transition} obj.{b};",
      "path/{a}{transition}{b} --flag",
    },
  },
  number_row = {
    style = "number_row",
    combo_ratio = 0.4,
    plain_ratio = 0.18,
    curated_ratio = 0.45,
    min_words = 12,
    max_words = 18,
    curated_templates = {
      "v{a}{b}.0 build {transition}",
      "port {a}{b}00 rate {transition}",
      "2026-{a}{b}-14 {transition}",
      "{transition} 42% 84% {transition}",
    },
  },
  thumb_cluster = {
    style = "thumb_cluster",
    combo_ratio = 0.34,
    plain_ratio = 0.25,
    curated_ratio = 0.42,
    min_words = 12,
    max_words = 18,
    newline_ratio = 0.18,
    curated_templates = {
      "{a} {b}\n{a} {b}",
      "go {transition} stop {transition}",
      "line {transition}\nnext {transition}",
      "tap {a} {b} press {transition}",
    },
  },
  unclassified = {
    style = "default",
    combo_ratio = 0.22,
    plain_ratio = 0.35,
    curated_ratio = 0.18,
    min_words = 16,
    max_words = 24,
    curated_templates = {
      "{transition} practice {transition}",
      "steady {transition} control",
    },
  },
}

local class_auto_weights = {
  same_finger = 1.2,
  cross_center = 1.15,
  cross_hand = 1.0,
  same_hand = 0.95,
  symbol_jump = 1.05,
  number_row = 1.0,
  thumb_cluster = 0.7,
  unclassified = 0.55,
}

local function get_class_display_name(id)
  return class_display_names[id] or id
end

local function get_class_description(id)
  return class_descriptions[id] or ""
end

local function get_class_generation_profile(id)
  return vim.tbl_extend("force", class_generation_profiles.unclassified, class_generation_profiles[id] or {})
end

local function get_class_auto_weight(id)
  return class_auto_weights[id] or 1.0
end

local function get_class_evidence_score(info)
  local examples = info.examples or {}
  local distinct = 0
  local top_count = 0
  local total_example_hits = 0

  for _, count in pairs(examples) do
    distinct = distinct + 1
    total_example_hits = total_example_hits + count
    if count > top_count then
      top_count = count
    end
  end

  local diversity_bonus = math.min(0.22, math.max(0, distinct - 1) * 0.06)
  local volume_bonus = math.min(0.12, math.max(0, info.total - 20) / 200)
  local concentration_penalty = 0
  if total_example_hits > 0 then
    local top_share = top_count / total_example_hits
    concentration_penalty = math.max(0, top_share - 0.7) * 0.5
  end

  local score = 0.82 + diversity_bonus + volume_bonus - concentration_penalty
  if score < 0.55 then
    score = 0.55
  elseif score > 1.2 then
    score = 1.2
  end
  return score, distinct
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
  local prev_prev_ch = nil
  local prev_prev_pos = nil
  for i = 1, #char_map do
    local entry = char_map[i]
    if entry.is_newline then
      prev_ch = nil
      prev_pos = nil
      prev_prev_ch = nil
      prev_prev_pos = nil
      goto continue_bi
    end

    if prev_ch then
      local bigram = prev_ch .. entry.char
      if not data.bigrams[bigram] then
        data.bigrams[bigram] = { total = 0, errors = 0 }
      end
      data.bigrams[bigram].total = data.bigrams[bigram].total + 1
      -- Count bigram as error if either position had an error
      local is_error = error_positions[prev_pos] or error_positions[i]
      if is_error then
        data.bigrams[bigram].errors = data.bigrams[bigram].errors + 1
      end

      local class_labels = classify_transition(prev_ch, entry.char)
      for _, class_id in ipairs(class_labels) do
        if not data.transition_classes[class_id] then
          data.transition_classes[class_id] = { total = 0, errors = 0, examples = {} }
        end
        local class_info = data.transition_classes[class_id]
        class_info.total = class_info.total + 1
        if is_error then
          class_info.errors = class_info.errors + 1
        end
        class_info.examples[bigram] = (class_info.examples[bigram] or 0) + 1
      end
    end

    if prev_prev_ch and prev_ch then
      local trigram = prev_prev_ch .. prev_ch .. entry.char
      if not data.trigrams[trigram] then
        data.trigrams[trigram] = { total = 0, errors = 0 }
      end
      data.trigrams[trigram].total = data.trigrams[trigram].total + 1
      if error_positions[prev_prev_pos] or error_positions[prev_pos] or error_positions[i] then
        data.trigrams[trigram].errors = data.trigrams[trigram].errors + 1
      end
    end

    prev_prev_ch = prev_ch
    prev_prev_pos = prev_pos
    prev_ch = entry.char
    prev_pos = i

    ::continue_bi::
  end

  for _, class_info in pairs(data.transition_classes) do
    if class_info.examples then
      class_info.examples = prune_class_examples(class_info.examples)
    end
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

local function enrich_bigram_item(item)
  local labels, a_meta, b_meta = classify_transition(item.bigram:sub(1, 1), item.bigram:sub(2, 2))
  item.class_ids = labels
  item.class_names = {}
  for _, class_id in ipairs(labels) do
    item.class_names[#item.class_names + 1] = get_class_display_name(class_id)
  end
  item.meta = { first = a_meta, second = b_meta }
  return item
end

--- Get the N worst bigrams by error rate.
--- @param n number
--- @param min_total? number (default 10)
--- @return { bigram: string, error_rate: number, total: number, errors: number, class_ids: string[], class_names: string[] }[]
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
    out[i] = enrich_bigram_item(results[i])
  end
  return out
end

--- Get the N worst trigrams by error rate.
--- @param n number
--- @param min_total? number (default 8)
--- @return { trigram: string, error_rate: number, total: number, errors: number }[]
function M.get_worst_trigrams(n, min_total)
  min_total = min_total or 8
  local data = load_data()
  local results = {}

  for tri, info in pairs(data.trigrams or {}) do
    if info.total >= min_total and info.errors > 0 then
      results[#results + 1] = {
        trigram = tri,
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

--- Get the N hardest transition classes by error rate.
--- @param n number
--- @param min_total? number (default 20)
--- @param opts? { weighted?: boolean }
--- @return { class_id: string, name: string, error_rate: number, total: number, errors: number, sample: string, auto_score?: number, evidence_score?: number, distinct_examples?: number }[]
function M.get_worst_transition_classes(n, min_total, opts)
  min_total = min_total or 20
  opts = opts or {}
  local data = load_data()
  local results = {}

  for class_id, info in pairs(data.transition_classes or {}) do
    if info.total >= min_total and info.errors > 0 then
      local sample = nil
      local sample_count = -1
      for bigram, count in pairs(info.examples or {}) do
        if count > sample_count then
          sample = bigram
          sample_count = count
        end
      end
      local evidence_score, distinct_examples = get_class_evidence_score(info)
      results[#results + 1] = {
        class_id = class_id,
        name = get_class_display_name(class_id),
        error_rate = info.errors / info.total,
        total = info.total,
        errors = info.errors,
        sample = sample or "--",
        evidence_score = evidence_score,
        distinct_examples = distinct_examples,
        auto_score = (info.errors / info.total) * get_class_auto_weight(class_id) * evidence_score,
      }
    end
  end

  table.sort(results, function(a, b)
    local a_score = opts.weighted and a.auto_score or a.error_rate
    local b_score = opts.weighted and b.auto_score or b.error_rate
    if a_score == b_score then
      return a.errors > b.errors
    end
    return a_score > b_score
  end)

  local out = {}
  for i = 1, math.min(n, #results) do
    out[i] = results[i]
  end
  return out
end

--- Return the catalog of transition classes for menus and explicit selection.
--- @return { id: string, name: string, description: string }[]
function M.get_transition_class_catalog()
  local out = {}
  for _, id in ipairs(class_order) do
    out[#out + 1] = {
      id = id,
      name = get_class_display_name(id),
      description = get_class_description(id),
    }
  end
  return out
end

--- Get a summary for display.
--- @return { worst_chars: table, worst_bigrams: table, worst_trigrams: table, worst_transition_classes: table, total_chars: number, total_errors: number, has_data: boolean }
function M.get_summary()
  local data = load_data()
  return {
    worst_chars = M.get_worst_chars(8),
    worst_bigrams = M.get_worst_bigrams(6),
    worst_trigrams = M.get_worst_trigrams(5),
    worst_transition_classes = M.get_worst_transition_classes(5, 10),
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
--- @return { bigram: string, total: number, errors: number, error_rate: number, class_ids: string[], class_names: string[] }[]
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
    out[#out + 1] = enrich_bigram_item(items[i])
  end
  return out
end

local function unique_transitions(items, field, max_items)
  local out = {}
  local seen = {}
  for _, item in ipairs(items) do
    local transition = item[field]
    if transition and not seen[transition] then
      seen[transition] = true
      out[#out + 1] = transition
      if #out >= max_items then
        break
      end
    end
  end
  return out
end

--- Get the hardest bigrams within a movement class.
--- @param class_id string
--- @param n number
--- @param min_total? number
--- @return { bigram: string, error_rate: number, total: number, errors: number, class_ids: string[], class_names: string[] }[]
function M.get_bigrams_for_class(class_id, n, min_total)
  local matches = {}
  for _, item in ipairs(M.get_worst_bigrams(200, min_total or 8)) do
    for _, candidate in ipairs(item.class_ids or {}) do
      if candidate == class_id then
        matches[#matches + 1] = item
        break
      end
    end
  end

  local out = {}
  for i = 1, math.min(n or 5, #matches) do
    out[#out + 1] = matches[i]
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

--- Generate a targeted exercise focusing on the user's hardest transitions.
--- @param opts? { min_words?: number, max_words?: number, min_transition_hits?: number }
--- @return string exercise_text
--- @return string description
function M.generate_transition_exercise(opts)
  opts = opts or {}
  local focus_class = nil
  if opts.class_id then
    focus_class = {
      class_id = opts.class_id,
      name = get_class_display_name(opts.class_id),
      sample = "--",
    }
  else
    focus_class = M.get_worst_transition_classes(1, 10, { weighted = true })[1]
  end
  local worst = focus_class and M.get_bigrams_for_class(focus_class.class_id, 5, 8) or {}
  if #worst == 0 then
    if opts.class_id then
      local text, desc = M.generate_targeted_exercise({
        min_words = opts.min_words or 14,
        max_words = opts.max_words or 22,
        min_focus_occurrences = opts.min_transition_hits or 12,
      })
      return text, "Focus: " .. get_class_display_name(opts.class_id) .. " | not enough class-specific data yet; " .. desc
    end
    -- Auto mode with no class-specific bigrams: drop the class focus so the
    -- generated drill and its description line up on the overall worst bigrams.
    focus_class = nil
    worst = M.get_worst_bigrams(5, 10)
  end
  if #worst == 0 then
    return M.generate_targeted_exercise({
      min_words = opts.min_words or 14,
      max_words = opts.max_words or 22,
      min_focus_occurrences = opts.min_transition_hits or 12,
    })
  end

  local transitions = unique_transitions(worst, "bigram", 4)
  local warmup = {}
  for _, transition in ipairs(transitions) do
    warmup[#warmup + 1] = string.format("%s %s%s %s", transition, transition, transition, transition)
  end

  local profile = get_class_generation_profile(focus_class and focus_class.class_id or "unclassified")

  local body = words.generate_transition_drill({
    transitions = transitions,
    style = profile.style,
    combo_ratio = profile.combo_ratio,
    plain_ratio = profile.plain_ratio,
    newline_ratio = profile.newline_ratio,
    curated_templates = profile.curated_templates,
    curated_ratio = profile.curated_ratio,
    allowed_chars = profile.allowed_chars,
    min_words = opts.min_words or profile.min_words or 16,
    max_words = opts.max_words or profile.max_words or 24,
    min_transition_hits = opts.min_transition_hits or math.max(10, #transitions * 4),
  })

  local desc_parts = {}
  for i = 1, math.min(3, #worst) do
    local class_name = nil
    if focus_class and focus_class.class_id and worst[i].class_ids then
      for idx, class_id in ipairs(worst[i].class_ids) do
        if class_id == focus_class.class_id then
          class_name = worst[i].class_names and worst[i].class_names[idx] or focus_class.name
          break
        end
      end
    end
    if not class_name and worst[i].class_names and worst[i].class_names[1] then
      class_name = worst[i].class_names[1]
    end
    local class_hint = class_name and (" / " .. class_name) or ""
    desc_parts[#desc_parts + 1] = string.format("'%s'%s (%.0f%%)", worst[i].bigram, class_hint, worst[i].error_rate * 100)
  end

  local prefix = "Targeting transitions"
  if focus_class then
    prefix = "Focus: " .. focus_class.name
    if focus_class.sample and focus_class.sample ~= "--" then
      prefix = prefix .. " via '" .. focus_class.sample .. "'"
    elseif #worst > 0 then
      prefix = prefix .. " via '" .. worst[1].bigram .. "'"
    end
  end

  return table.concat({
    table.concat(warmup, "    "),
    body,
  }, "\n"), prefix .. " | " .. table.concat(desc_parts, ", ")
end

--- Check if there is enough data for transition-focused exercises.
--- @return boolean
function M.has_enough_transition_data()
  local data = load_data()
  if data.total_chars < 120 then
    return false
  end
  for _, info in pairs(data.bigrams or {}) do
    if info.total >= 10 and info.errors > 0 then
      return true
    end
  end
  return false
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
    trigrams = {},
    transition_classes = {},
    total_chars = 0,
    total_errors = 0,
    last_updated = "",
  }
  save_data()
end

return M
