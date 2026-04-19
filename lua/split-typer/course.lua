local storage = require("split-typer.storage")
local errs = require("split-typer.errors")
local words = require("split-typer.words")
local layouts = require("split-typer.layouts")

local M = {}

local PROGRESS_SCHEMA = 3
local VALIDATION_DELAY_SECS = 8 * 60 * 60

-- Stage definitions. Each level runs every stage; the stage's deltas/scale
-- modify the level's baseline gates. A stage is "passed" once it has been
-- cleared `reps_required` times; once passed, it's still re-playable but no
-- longer required to advance.
local stage_defs = {
  {
    id = "single_key",
    name = "Single Key",
    short = "SK",
    description = "Isolated presses of the newly unlocked keys",
    wpm_scale = 1.0,
    acc_delta = 1,
    eff_delta = 2,
    max_err_delta = 0,
    reps_required = 2,
    guided_until_level = 3,
    early_wpm_relief = 2,
  },
  {
    id = "bigrams",
    name = "Bigrams",
    short = "BG",
    description = "Adjacent pair drills - new keys against each other and prior keys",
    wpm_scale = 0.95,
    acc_delta = 0,
    eff_delta = 0,
    max_err_delta = 1,
    reps_required = 2,
    guided_until_level = 3,
    early_wpm_relief = 2,
  },
  {
    id = "focused",
    name = "Focused Words",
    short = "FW",
    description = "Words that lean heavily on the new keys",
    wpm_scale = 0.9,
    acc_delta = -1,
    eff_delta = -1,
    max_err_delta = 1,
    reps_required = 2,
    early_wpm_relief = 1,
  },
  {
    id = "integration",
    name = "Integration",
    short = "IN",
    description = "All unlocked keys mixed - adaptive to your weak spots",
    wpm_scale = 1.0,
    acc_delta = 0,
    eff_delta = 0,
    max_err_delta = 0,
    reps_required = 2,
  },
  {
    id = "mastery",
    name = "Mastery",
    short = "MA",
    description = "Longer integration run with a tighter gate",
    wpm_scale = 1.1,
    acc_delta = 1,
    eff_delta = 2,
    max_err_delta = -1,
    reps_required = 2,
    course_mode = "mastery",
  },
}

-- Templates describe each level in terms of physical positions on the columnar
-- grid (row × column). A resolver renders the glyphs from the active layout,
-- so the same 12-level progression produces QWERTY chars on QWERTY, Dvorak
-- chars on Dvorak, and so on. Baseline gates here apply to all stages; each
-- stage def shifts them.
local level_templates = {
  { id = 1,  static_name = "Home Row",
    new_positions = { { row = "home", cols = { 1, 2, 3, 4, 7, 8, 9, 10 } } },
    description = "Find your home position on the columnar grid",
    base_wpm = 10, base_acc = 94, base_eff = 88, base_max_err = 5,
    words_range = { 10, 16 } },
  { id = 2,
    new_positions = { { row = "top", cols = { 3, 8 } } },
    description = "Middle fingers reach up to the top row",
    base_wpm = 12, base_acc = 94, base_eff = 88, base_max_err = 5,
    words_range = { 10, 18 } },
  { id = 3,
    new_positions = { { row = "top", cols = { 4, 7 } } },
    description = "Index fingers reach up to the top row",
    base_wpm = 14, base_acc = 94, base_eff = 89, base_max_err = 5,
    words_range = { 12, 18 } },
  { id = 4,
    new_positions = { { row = "home", cols = { 5, 6 } } },
    description = "Index fingers reach inward - the split boundary",
    base_wpm = 16, base_acc = 94, base_eff = 89, base_max_err = 5,
    words_range = { 12, 18 } },
  { id = 5,
    new_positions = { { row = "top", cols = { 5, 6 } } },
    description = "Center column top row - another split challenge",
    base_wpm = 18, base_acc = 95, base_eff = 90, base_max_err = 4,
    words_range = { 12, 20 } },
  { id = 6,
    new_positions = { { row = "top", cols = { 2, 9 } } },
    description = "Ring fingers reach up to the top row",
    base_wpm = 20, base_acc = 95, base_eff = 90, base_max_err = 4,
    words_range = { 12, 20 } },
  { id = 7,
    new_positions = { { row = "top", cols = { 1, 10 } } },
    description = "Pinkies reach up - full top row complete",
    base_wpm = 22, base_acc = 95, base_eff = 91, base_max_err = 4,
    words_range = { 12, 20 } },
  { id = 8,
    new_positions = { { row = "bottom", cols = { 3, 4, 5 } } },
    description = "Left hand reaches down to the bottom row",
    base_wpm = 24, base_acc = 96, base_eff = 91, base_max_err = 4,
    words_range = { 14, 22 } },
  { id = 9,
    new_positions = { { row = "bottom", cols = { 6, 7, 8 } } },
    description = "Right hand reaches down to the bottom row",
    base_wpm = 26, base_acc = 96, base_eff = 92, base_max_err = 3,
    words_range = { 14, 22 } },
  { id = 10,
    new_positions = { { row = "bottom", cols = { 1, 2, 9, 10 } } },
    description = "Complete the bottom row - all letter keys unlocked",
    base_wpm = 28, base_acc = 96, base_eff = 92, base_max_err = 3,
    words_range = { 14, 22 } },
  { id = 11, static_name = "Numbers",
    new_positions = { { row = "number", cols = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } } },
    description = "Top row numbers on the columnar grid",
    base_wpm = 22, base_acc = 95, base_eff = 90, base_max_err = 4,
    words_range = { 12, 18 } },
  { id = 12, static_name = "Full Mastery",
    include_shifted_numbers = true, include_extras = true,
    description = "All keys - prove your mastery of the split keyboard",
    base_wpm = 30, base_acc = 97, base_eff = 93, base_max_err = 3,
    words_range = { 14, 22 } },
}

local function chars_from_positions(positions_list)
  local out = {}
  local rows = layouts.active and layouts.active.rows or {}
  for _, spec in ipairs(positions_list or {}) do
    local glyphs = rows[spec.row]
    if glyphs then
      for _, col in ipairs(spec.cols) do
        local ch = glyphs[col]
        if ch then out[#out + 1] = ch end
      end
    end
  end
  return out
end

local function chars_from_extras()
  local out = {}
  for _, group in ipairs(layouts.active and layouts.active.extras or {}) do
    for _, ch in ipairs(group.chars) do
      out[#out + 1] = ch
    end
  end
  return out
end

local function derive_name(static_name, new_list)
  if static_name then return static_name end
  local pieces = {}
  for _, ch in ipairs(new_list) do
    pieces[#pieces + 1] = ch:match("%a") and ch:upper() or ch
  end
  return "+ " .. table.concat(pieces, " ")
end

local function clamp_acc(v)
  if v < 80 then return 80 end
  if v > 99 then return 99 end
  return v
end

local function build_stage_gate(level, stage_def)
  local wpm = math.floor(level.base_wpm * stage_def.wpm_scale + 0.5)
  if level.id <= 3 and stage_def.early_wpm_relief then
    wpm = wpm - stage_def.early_wpm_relief
  end
  wpm = math.max(6, wpm)
  local acc = clamp_acc(level.base_acc + stage_def.acc_delta)
  local eff = clamp_acc(level.base_eff + stage_def.eff_delta)
  local max_err = math.max(1, level.base_max_err + stage_def.max_err_delta)
  local course_mode = stage_def.course_mode
  if not course_mode then
    if level.id <= (stage_def.guided_until_level or 0) then
      course_mode = "guided"
    else
      course_mode = "clean"
    end
  end
  return {
    id = stage_def.id,
    name = stage_def.name,
    short = stage_def.short,
    description = stage_def.description,
    req_wpm = wpm,
    req_accuracy = acc,
    req_efficiency = eff,
    req_max_errors = max_err,
    reps_required = stage_def.reps_required,
    course_mode = course_mode,
    no_backspace = course_mode ~= "guided",
  }
end

local function materialize_level(template, prior_chars)
  local new_list = chars_from_positions(template.new_positions)
  if template.include_shifted_numbers and layouts.active then
    for _, ch in ipairs(layouts.active.shifted_number_row or {}) do
      new_list[#new_list + 1] = ch
    end
  end
  if template.include_extras then
    for _, ch in ipairs(chars_from_extras()) do
      new_list[#new_list + 1] = ch
    end
  end

  local new_chars = table.concat(new_list)
  local level = {
    id = template.id,
    name = derive_name(template.static_name, new_list),
    new_chars = new_chars,
    all_chars = prior_chars .. new_chars,
    description = template.description,
    base_wpm = template.base_wpm,
    base_acc = template.base_acc,
    base_eff = template.base_eff,
    base_max_err = template.base_max_err,
    words_range = template.words_range,
    include_shifted_numbers = template.include_shifted_numbers,
    include_extras = template.include_extras,
  }
  level.stages = {}
  for _, sd in ipairs(stage_defs) do
    level.stages[#level.stages + 1] = build_stage_gate(level, sd)
  end
  return level
end

local function materialize_all()
  local out = {}
  local accum = ""
  for _, tpl in ipairs(level_templates) do
    local lvl = materialize_level(tpl, accum)
    out[#out + 1] = lvl
    accum = lvl.all_chars
  end
  return out
end

M.levels = materialize_all()
M.stage_defs = stage_defs

--- Rebuild the level table after a layout change.
function M.rebuild_for_layout()
  M.levels = materialize_all()
  _progress = nil
end

-- ============================================================
-- Stage exercise generators
-- ============================================================

local function shuffle_in_place(list)
  for i = #list, 2, -1 do
    local j = math.random(1, i)
    list[i], list[j] = list[j], list[i]
  end
end

local function char_at(str, i)
  return str:sub(i, i)
end

local function gen_single_key(level)
  local pool = level.new_chars
  if #pool == 0 then pool = level.all_chars end
  -- Scale group count by pool size so 2-new-char levels still get a decent run.
  local tokens = {}
  local target_tokens = math.max(18, math.min(34, 8 + #pool * 3))
  for _ = 1, target_tokens do
    local ch = char_at(pool, math.random(1, #pool))
    local reps = math.random(3, 5)
    tokens[#tokens + 1] = string.rep(ch, reps)
  end
  -- Interleave a handful of prior-key groups so thumbs/space rhythm still
  -- gets exercised and the drill doesn't feel identical every time.
  if level.all_chars ~= level.new_chars and #level.all_chars > #level.new_chars then
    local prior = level.all_chars:sub(1, #level.all_chars - #level.new_chars)
    if #prior > 0 then
      local n = math.max(3, math.floor(target_tokens * 0.2))
      for _ = 1, n do
        local ch = char_at(prior, math.random(1, #prior))
        tokens[#tokens + 1] = string.rep(ch, math.random(2, 4))
      end
      shuffle_in_place(tokens)
    end
  end
  return table.concat(tokens, " ")
end

local function gen_bigrams(level)
  local new = level.new_chars
  if #new == 0 then new = level.all_chars end
  local prior = ""
  if level.all_chars ~= new and #level.all_chars > #new then
    prior = level.all_chars:sub(1, #level.all_chars - #new)
  end

  local bigrams = {}
  local seen = {}
  local function add(a, b)
    if a == " " or b == " " then return end
    local bg = a .. b
    if not seen[bg] then
      seen[bg] = true
      bigrams[#bigrams + 1] = bg
    end
  end

  -- Pair new chars with each other.
  for i = 1, #new do
    for j = 1, #new do
      if i ~= j then
        add(char_at(new, i), char_at(new, j))
      end
    end
  end
  -- Pair new chars with a spread of prior chars.
  if #prior > 0 then
    for i = 1, #new do
      local a = char_at(new, i)
      for _ = 1, math.min(5, #prior) do
        local b = char_at(prior, math.random(1, #prior))
        add(a, b)
        add(b, a)
      end
    end
  end

  if #bigrams == 0 then
    return gen_single_key(level)
  end

  local forms = {
    function(bg) return bg .. bg end,
    function(bg) return bg .. bg .. bg end,
    function(bg) return bg .. " " .. bg end,
    function(bg) return bg:sub(2, 2) .. bg end,
    function(bg) return bg .. bg:sub(1, 1) end,
  }

  local tokens = {}
  local target = math.random(22, 30)
  for _ = 1, target do
    local bg = bigrams[math.random(1, #bigrams)]
    local f = forms[math.random(1, #forms)]
    tokens[#tokens + 1] = f(bg)
  end
  return table.concat(tokens, " ")
end

local function focus_seed(level)
  if #level.new_chars > 0 then
    return level.new_chars
  end
  return level.all_chars
end

local function gen_focused(level)
  local seed = focus_seed(level)
  local min_w = level.words_range[1]
  local max_w = level.words_range[2]
  return words.generate({
    chars = level.all_chars,
    focus_chars = seed,
    min_focus_density = 0.25,
    min_focus_occurrences = math.max(10, #seed * 4),
    min_words = min_w,
    max_words = max_w,
  })
end

local function gen_integration(level)
  local adaptive_focus = errs.get_adaptive_focus_chars({
    allowed_chars = level.all_chars,
    seed_chars = level.new_chars,
    limit = 5,
    min_total = 12,
  })
  return words.generate({
    chars = level.all_chars,
    focus_chars = adaptive_focus,
    min_focus_occurrences = math.max(12, #adaptive_focus * 4),
    min_words = level.words_range[1] + 2,
    max_words = level.words_range[2] + 4,
  })
end

local function generate_mastery_mix(level)
  local parts = {}
  local num_parts = math.random(20, 28)
  local word_pool = words.filter("abcdefghijklmnopqrstuvwxyz")

  local symbol_patterns = {
    "()", "{}", "[]", "<>", "!=", "==", "+=", "->", "=>", "||",
    "&&", "<=", ">=", "++", "--", "::", "..", "**", "//", "??",
    "#{}", "${}", "[0]", "(i)", "{k: v}", "a[i]", "f(x)", "!ok",
    "a + b", "x - y", "n * m", "p / q", "i % 2", "a ^ b",
    "@name", "#tag", "$val", "&ref", "*ptr",
  }

  local number_patterns = {
    "42", "100", "255", "1024", "8080", "3.14", "0xff", "1e10",
    "192.168.1.1", "127.0.0.1", "80/tcp", "v2.1", "2026-04-14",
  }

  for i = 1, num_parts do
    local roll = math.random()
    if roll < 0.55 then
      if #word_pool > 0 then
        parts[i] = word_pool[math.random(1, #word_pool)]
      else
        parts[i] = words.combo("abcdefghijklmnopqrstuvwxyz", math.random(3, 6))
      end
    elseif roll < 0.78 then
      parts[i] = symbol_patterns[math.random(1, #symbol_patterns)]
    else
      parts[i] = number_patterns[math.random(1, #number_patterns)]
    end
  end

  return table.concat(parts, " ")
end

local function gen_mastery(level)
  if level.include_shifted_numbers or level.include_extras then
    return generate_mastery_mix(level)
  end
  local adaptive_focus = errs.get_adaptive_focus_chars({
    allowed_chars = level.all_chars,
    seed_chars = level.new_chars,
    limit = 6,
    min_total = 14,
  })
  return words.generate({
    chars = level.all_chars,
    focus_chars = adaptive_focus,
    min_focus_occurrences = math.max(16, #adaptive_focus * 5),
    min_words = level.words_range[2] + 6,
    max_words = level.words_range[2] + 12,
  })
end

local stage_generators = {
  single_key = gen_single_key,
  bigrams = gen_bigrams,
  focused = gen_focused,
  integration = gen_integration,
  mastery = gen_mastery,
}

-- ============================================================
-- Progress persistence
-- ============================================================

local _progress = nil

local function get_progress_file()
  return storage.layout_data_path("progress")
end

local function warn_save_failure()
  vim.schedule(function()
    vim.notify("split-typer: failed to save course progress", vim.log.levels.WARN)
  end)
end

local function blank_progress()
  return { schema_version = PROGRESS_SCHEMA, current_level = 1, levels = {} }
end

local function blank_stage_progress()
  return {
    completed = 0,
    passed = false,
    validated = false,
    validation_runs = 0,
    first_pass_at = nil,
    last_pass_at = nil,
    validated_at = nil,
    best_wpm = 0,
    best_accuracy = 0,
  }
end

local function blank_level_progress()
  return {
    stages = {},
    passed = false,
    validated = false,
    validated_at = nil,
    best_wpm = 0,
    best_accuracy = 0,
  }
end

local function upgrade_progress(loaded)
  if loaded.schema_version == PROGRESS_SCHEMA then
    return loaded
  end

  local upgraded = blank_progress()
  upgraded.current_level = loaded.current_level or 1

  if type(loaded.levels) == "table" then
    for level_key, old_lp in pairs(loaded.levels) do
      if type(old_lp) == "table" then
        local new_lp = blank_level_progress()
        new_lp.passed = old_lp.passed or false
        new_lp.validated = old_lp.validated or false
        new_lp.validated_at = old_lp.validated_at
        new_lp.best_wpm = old_lp.best_wpm or 0
        new_lp.best_accuracy = old_lp.best_accuracy or 0

        if type(old_lp.stages) == "table" then
          for _, sd in ipairs(stage_defs) do
            local old_sp = old_lp.stages[sd.id]
            if type(old_sp) == "table" then
              local new_sp = blank_stage_progress()
              new_sp.completed = old_sp.completed or 0
              new_sp.passed = old_sp.passed or false
              if loaded.schema_version >= 3 then
                new_sp.validated = old_sp.validated or false
                new_sp.validation_runs = old_sp.validation_runs or 0
                new_sp.first_pass_at = old_sp.first_pass_at
                new_sp.last_pass_at = old_sp.last_pass_at
                new_sp.validated_at = old_sp.validated_at
              else
                -- Preserve prior course completion when upgrading from the
                -- old pass-only schema; new work will require delayed
                -- validation, but historical progress stays intact.
                new_sp.validated = new_sp.passed
                new_sp.validation_runs = new_sp.passed and 1 or 0
              end
              new_sp.best_wpm = old_sp.best_wpm or 0
              new_sp.best_accuracy = old_sp.best_accuracy or 0
              new_lp.stages[sd.id] = new_sp
            end
          end
        end

        if not old_lp.validated and loaded.schema_version < 3 then
          new_lp.validated = new_lp.passed
          if new_lp.validated then
            new_lp.validated_at = old_lp.validated_at
          end
        end

        upgraded.levels[level_key] = new_lp
      end
    end
  end

  upgraded.schema_version = PROGRESS_SCHEMA
  return upgraded
end

--- Load progress from disk, resetting if the on-disk schema pre-dates stages.
--- @return table
function M.load_progress()
  if _progress then
    return _progress
  end

  local progress_file = get_progress_file()
  local loaded = storage.read_json(progress_file, blank_progress())
  if loaded.schema_version ~= PROGRESS_SCHEMA then
    loaded = upgrade_progress(loaded)
    storage.write_json(progress_file, loaded)
  end
  _progress = loaded
  return _progress
end

--- Save progress to disk.
function M.save_progress()
  if not _progress then
    return
  end
  if not storage.write_json(get_progress_file(), _progress) then
    warn_save_failure()
  end
end

--- Get progress for a specific level.
--- @param level_id number
--- @return table
function M.get_level_progress(level_id)
  local prog = M.load_progress()
  local key = tostring(level_id)
  if not prog.levels[key] then
    prog.levels[key] = blank_level_progress()
  end
  local lp = prog.levels[key]
  lp.stages = lp.stages or {}
  lp.best_wpm = lp.best_wpm or 0
  lp.best_accuracy = lp.best_accuracy or 0
  lp.passed = lp.passed or false
  lp.validated = lp.validated or false

  for _, sd in ipairs(stage_defs) do
    if not lp.stages[sd.id] then
      lp.stages[sd.id] = blank_stage_progress()
    end
    local sp = lp.stages[sd.id]
    sp.completed = sp.completed or 0
    sp.passed = sp.passed or false
    sp.validated = sp.validated or false
    sp.validation_runs = sp.validation_runs or 0
    sp.best_wpm = sp.best_wpm or 0
    sp.best_accuracy = sp.best_accuracy or 0
  end
  return lp
end

--- Get progress for a stage within a level.
--- @param level_id number
--- @param stage_id string
--- @return table
function M.get_stage_progress(level_id, stage_id)
  local lp = M.get_level_progress(level_id)
  return lp.stages[stage_id] or blank_stage_progress()
end

--- Find the stage definition on a level.
local function find_stage(level, stage_id)
  for _, s in ipairs(level.stages) do
    if s.id == stage_id then return s end
  end
  return nil
end

local function all_stages_passed(lp)
  for _, sd in ipairs(stage_defs) do
    local sp = lp.stages[sd.id]
    if not sp or not sp.passed then
      return false
    end
  end
  return true
end

local function all_stages_validated(lp)
  for _, sd in ipairs(stage_defs) do
    local sp = lp.stages[sd.id]
    if not sp or not sp.validated then
      return false
    end
  end
  return true
end

local function validation_ready(sp, now_ts)
  if not sp or not sp.first_pass_at then
    return false
  end
  return (now_ts - sp.first_pass_at) >= VALIDATION_DELAY_SECS
end

--- Record a completed exercise for a specific stage and check for progress.
--- @param level_id number
--- @param stage_id string
--- @param wpm number
--- @param accuracy number
--- @param efficiency number
--- @param errors number
--- @return boolean passed_exercise Whether the exercise met the stage gate
--- @return boolean stage_cleared Whether the stage just became passed
--- @return boolean stage_validated Whether the stage just became validated
--- @return boolean level_complete Whether the level just became pass-complete
--- @return boolean level_validated Whether the level just became fully validated
function M.record_exercise(level_id, stage_id, wpm, accuracy, efficiency, errors)
  local level = M.get_level(level_id)
  if not level then return false, false, false, false, false end
  local stage = find_stage(level, stage_id)
  if not stage then return false, false, false, false, false end

  local lp = M.get_level_progress(level_id)
  local sp = lp.stages[stage_id]

  if wpm > sp.best_wpm then sp.best_wpm = wpm end
  if accuracy > sp.best_accuracy then sp.best_accuracy = accuracy end
  if wpm > lp.best_wpm then lp.best_wpm = wpm end
  if accuracy > lp.best_accuracy then lp.best_accuracy = accuracy end

  local passed = wpm >= stage.req_wpm
    and accuracy >= stage.req_accuracy
    and efficiency >= stage.req_efficiency
    and errors <= stage.req_max_errors

  local stage_cleared = false
  local stage_validated = false
  if passed then
    local now_ts = os.time()
    local was_passed = sp.passed
    local was_validated = sp.validated
    if not sp.first_pass_at then
      sp.first_pass_at = now_ts
    end
    sp.last_pass_at = now_ts
    sp.completed = (sp.completed or 0) + 1
    if not was_passed and sp.completed >= stage.reps_required then
      sp.passed = true
      stage_cleared = true
    elseif was_passed and not was_validated and validation_ready(sp, now_ts) then
      sp.validated = true
      sp.validated_at = now_ts
      sp.validation_runs = (sp.validation_runs or 0) + 1
      stage_validated = true
    end
  end

  local level_complete = false
  if not lp.passed and all_stages_passed(lp) then
    lp.passed = true
    level_complete = true
    local prog = M.load_progress()
    if prog.current_level == level_id and level_id < #M.levels then
      prog.current_level = level_id + 1
    end
  end

  local level_validated = false
  if not lp.validated and all_stages_validated(lp) then
    lp.validated = true
    lp.validated_at = os.time()
    level_validated = true
  end

  M.save_progress()
  return passed, stage_cleared, stage_validated, level_complete, level_validated
end

--- Check if a level is unlocked.
--- @param level_id number
--- @return boolean
function M.is_unlocked(level_id)
  if level_id == 1 then return true end
  local prev = M.get_level_progress(level_id - 1)
  return prev.passed
end

--- Get level definition by ID.
--- @param level_id number
--- @return table|nil
function M.get_level(level_id)
  for _, lvl in ipairs(M.levels) do
    if lvl.id == level_id then return lvl end
  end
  return nil
end

--- Get the current (highest unlocked) level ID.
--- @return number
function M.get_current_level()
  local prog = M.load_progress()
  return prog.current_level or 1
end

--- Return the next level that deserves attention: first incomplete level,
--- then the first passed-but-unvalidated level, else the current unlocked one.
--- @return number
function M.get_focus_level()
  for _, level in ipairs(M.levels) do
    if M.is_unlocked(level.id) then
      local lp = M.get_level_progress(level.id)
      if not lp.passed then
        return level.id
      end
    end
  end
  for _, level in ipairs(M.levels) do
    if M.is_unlocked(level.id) then
      local lp = M.get_level_progress(level.id)
      if lp.passed and not lp.validated then
        return level.id
      end
    end
  end
  return M.get_current_level()
end

--- Return the list of stage ids that still need to be cleared for this level.
--- Empty list means the level is done (all stages already passed).
--- @param level_id number
--- @return string[]
function M.pending_stages(level_id)
  local lp = M.get_level_progress(level_id)
  local pending = {}
  for _, sd in ipairs(stage_defs) do
    local sp = lp.stages[sd.id]
    if not sp or not sp.passed then
      pending[#pending + 1] = sd.id
    end
  end
  return pending
end

--- Return stages that are passed but still waiting on delayed validation.
--- @param level_id number
--- @return string[]
function M.pending_validation_stages(level_id)
  local lp = M.get_level_progress(level_id)
  local pending = {}
  for _, sd in ipairs(stage_defs) do
    local sp = lp.stages[sd.id]
    if sp and sp.passed and not sp.validated then
      pending[#pending + 1] = sd.id
    end
  end
  return pending
end

--- Pick the next stage to play for a level. Prefers pending stages (random
--- among them), then validation work, then falls back to a random stage if
--- everything is already passed and validated.
--- @param level_id number
--- @return string|nil stage_id
function M.pick_next_stage(level_id)
  local pending = M.pending_stages(level_id)
  if #pending > 0 then
    return pending[math.random(1, #pending)]
  end
  local validation_pending = M.pending_validation_stages(level_id)
  if #validation_pending > 0 then
    return validation_pending[math.random(1, #validation_pending)]
  end
  return stage_defs[math.random(1, #stage_defs)].id
end

--- Generate an exercise for a specific stage of a level.
--- @param level_id number
--- @param stage_id string
--- @return string
function M.generate_exercise(level_id, stage_id)
  local level = M.get_level(level_id)
  if not level then return "error: level not found" end
  local gen = stage_generators[stage_id]
  if not gen then return "error: stage not found" end
  return gen(level)
end

--- Return typing-session options for a given course stage.
--- @param level_id number
--- @param stage_id string
--- @return table
function M.get_stage_session_opts(level_id, stage_id)
  local stage = M.get_stage(level_id, stage_id)
  if not stage then
    return { no_backspace = true }
  end
  return {
    no_backspace = stage.no_backspace,
  }
end

--- Look up a stage definition (gate values) on a level.
--- @param level_id number
--- @param stage_id string
--- @return table|nil
function M.get_stage(level_id, stage_id)
  local level = M.get_level(level_id)
  if not level then return nil end
  return find_stage(level, stage_id)
end

--- @param level_id number
--- @param stage_id string
--- @param now_ts? number
--- @return boolean
function M.is_stage_validation_ready(level_id, stage_id, now_ts)
  local sp = M.get_stage_progress(level_id, stage_id)
  now_ts = now_ts or os.time()
  return validation_ready(sp, now_ts)
end

--- @param level_id number
--- @param stage_id string
--- @param now_ts? number
--- @return number|nil
function M.get_stage_validation_due_at(level_id, stage_id, now_ts)
  local sp = M.get_stage_progress(level_id, stage_id)
  if not sp or not sp.first_pass_at then
    return nil
  end
  now_ts = now_ts or os.time()
  if validation_ready(sp, now_ts) then
    return now_ts
  end
  return sp.first_pass_at + VALIDATION_DELAY_SECS
end

function M.get_validation_delay_secs()
  return VALIDATION_DELAY_SECS
end

--- Reset all course progress.
function M.reset_progress()
  _progress = blank_progress()
  M.save_progress()
end

return M
