local M = {}

local function show_no_backspace_flash(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local flash_ns = vim.api.nvim_create_namespace("split_typer_flash")
  vim.api.nvim_buf_clear_namespace(state.buf, flash_ns, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(state.buf)
  vim.api.nvim_buf_set_extmark(state.buf, flash_ns, line_count - 1, 0, {
    virt_lines = {
      { { "", "" } },
      { { "  BACKSPACE DISABLED - commit to every keystroke", "SplitTyperBad" } },
    },
  })
  vim.defer_fn(function()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      vim.api.nvim_buf_clear_namespace(state.buf, flash_ns, 0, -1)
    end
  end, 1200)
end

local function show_accuracy_gate_flash(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local flash_ns = vim.api.nvim_create_namespace("split_typer_accuracy_flash")
  vim.api.nvim_buf_clear_namespace(state.buf, flash_ns, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(state.buf)
  vim.api.nvim_buf_set_extmark(state.buf, flash_ns, line_count - 1, 0, {
    virt_lines = {
      { { "", "" } },
      { { "  ACCURACY GATE MISSED - exercise failed immediately", "SplitTyperBad" } },
    },
  })
  vim.defer_fn(function()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      vim.api.nvim_buf_clear_namespace(state.buf, flash_ns, 0, -1)
    end
  end, 1400)
end

local function append_timed_chunk(ctx)
  local state = ctx.state
  if not state.timed_mode or not state.chunk_generator then
    return
  end

  local chunk = state.chunk_generator()
  if not chunk or #chunk == 0 then
    return
  end

  local combined = state.target and (#state.target > 0 and (state.target .. "\n" .. chunk) or chunk) or chunk
  state.target = combined
  state.char_map = ctx.state_mod.build_char_map(combined)

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, -1, -1, false, vim.split(chunk, "\n"))
    vim.bo[state.buf].modifiable = false
  end
end

local function finish_session(ctx)
  local state = ctx.state
  if state.finished then
    return
  end

  state.finished = true
  state.end_time = vim.uv.hrtime()
  if state.timer then
    state.timer:stop()
  end
  vim.defer_fn(function()
    ctx.save_stats()
    if state.mode == "course" then
      ctx.actions.show_course_results()
    else
      ctx.actions.show_results()
    end
  end, 300)
end

function M.setup_keymaps(ctx)
  local state = ctx.state
  local map = ctx.window.map
  local chars = "abcdefghijklmnopqrstuvwxyz"
    .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    .. "0123456789"
    .. "`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/? "

  for i = 1, #chars do
    local c = chars:sub(i, i)
    local lhs = c
    if c == " " then
      lhs = "<Space>"
    elseif c == "|" then
      lhs = "<Bar>"
    elseif c == "\\" then
      lhs = "<Bslash>"
    elseif c == "<" then
      lhs = "<lt>"
    end
    map(state, lhs, function()
      M.handle_typed_char(ctx, c)
    end)
  end

  map(state, "<CR>", function()
    M.handle_typed_char(ctx, "\n")
  end)
  map(state, "<BS>", function()
    if state.no_backspace then
      show_no_backspace_flash(ctx)
    else
      M.handle_backspace(ctx)
    end
  end)
  map(state, "<Tab>", function()
    M.handle_typed_char(ctx, "\t")
  end)
  map(state, "<Esc>", function()
    if state.mode == "course" then
      ctx.actions.show_course()
    else
      ctx.actions.show_menu()
    end
  end)
  map(state, "<C-c>", ctx.actions.cleanup)

  for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>", "<C-w>" }) do
    map(state, key, function() end)
  end
end

function M.start_stats_timer(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.timer = vim.uv.new_timer()
  state.timer:start(
    500,
    500,
    vim.schedule_wrap(function()
      if state.screen == "exercise" and not state.finished then
        if state.timed_mode and state.start_time and state.timed_deadline and vim.uv.hrtime() >= state.timed_deadline then
          finish_session(ctx)
          return
        end
        M.update_stats_header(ctx)
      end
    end)
  )
end

function M.handle_typed_char(ctx, char)
  local state = ctx.state
  if state.finished or state.pos >= #state.char_map then
    return
  end
  if state.timed_mode and state.start_time and state.timed_deadline and vim.uv.hrtime() >= state.timed_deadline then
    finish_session(ctx)
    return
  end

  if not state.start_time then
    state.start_time = vim.uv.hrtime()
    if state.timed_mode and state.timed_duration > 0 then
      state.timed_deadline = state.start_time + (state.timed_duration * 1e9)
    end
    M.start_stats_timer(ctx)
  end

  state.keystroke_count = state.keystroke_count + 1
  state.pos = state.pos + 1
  state.input[state.pos] = char

  local expected = state.char_map[state.pos].char
  if char ~= expected then
    state.error_count = state.error_count + 1
    state.streak = 0
    state.error_log[#state.error_log + 1] = {
      expected = expected,
      actual = char,
      pos = state.pos,
    }
  else
    state.correct_count = state.correct_count + 1
    state.streak = state.streak + 1
    if state.streak > state.best_streak then
      state.best_streak = state.streak
    end
  end

  state.key_events[#state.key_events + 1] = {
    t = vim.uv.hrtime(),
    kind = "type",
    correct = char == expected,
    pos = state.pos,
  }

  if state.error_limit ~= nil and state.error_count > state.error_limit then
    state.fail_reason = string.format("Accuracy gate missed: %d/%d errors", state.error_count, state.error_limit)
    state.failed_early = true
    show_accuracy_gate_flash(ctx)
    finish_session(ctx)
    return
  end

  if state.timed_mode and (#state.char_map - state.pos) < 80 then
    append_timed_chunk(ctx)
  end

  if state.pos >= #state.char_map then
    if state.timed_mode then
      append_timed_chunk(ctx)
    else
      finish_session(ctx)
    end
  end

  M.update_display(ctx)
end

function M.handle_backspace(ctx)
  local state = ctx.state
  if state.finished or state.pos <= 0 then
    return
  end

  state.keystroke_count = state.keystroke_count + 1
  state.backspace_count = state.backspace_count + 1
  state.streak = 0
  state.key_events[#state.key_events + 1] = {
    t = vim.uv.hrtime(),
    kind = "backspace",
    pos = state.pos,
  }
  if state.input[state.pos] == state.char_map[state.pos].char then
    state.correct_count = state.correct_count - 1
  end
  state.input[state.pos] = nil
  state.pos = state.pos - 1

  M.update_display(ctx)
end

function M.update_stats_header(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or not state.ns then
    return
  end

  local stats = ctx.state_mod.get_stats(state)
  local cat = ctx.exercises.get_category(state.category_id)
  local cat_name = cat and cat.name or "?"
  if state.mode == "course" and state.course_level then
    local level = ctx.course.get_level(state.course_level)
    cat_name = level and ("Course: " .. level.name) or cat_name
  elseif state.timed_mode then
    cat_name = "Timed Practice"
  elseif state.category_id == "targeted_practice" then
    cat_name = "Weak Key Practice"
  elseif state.category_id == "transition_practice" then
    cat_name = "Weak Transitions"
  end
  local progress = string.format("%d/%d", state.pos, #state.char_map)
  if state.timed_mode then
    progress = tostring(state.pos) .. " chars"
  end

  if state.header_extmark then
    pcall(vim.api.nvim_buf_del_extmark, state.buf, state.ns, state.header_extmark)
  end

  local wpm_hl = "SplitTyperStats"
  if stats.wpm >= 60 then
    wpm_hl = "SplitTyperGood"
  elseif stats.wpm >= 30 then
    wpm_hl = "SplitTyperOk"
  end

  local acc_hl = "SplitTyperStats"
  if stats.accuracy >= 95 then
    acc_hl = "SplitTyperGood"
  elseif stats.accuracy >= 80 then
    acc_hl = "SplitTyperOk"
  else
    acc_hl = "SplitTyperBad"
  end

  local eff_hl = "SplitTyperStats"
  if stats.efficiency >= 95 then
    eff_hl = "SplitTyperGood"
  elseif stats.efficiency >= 85 then
    eff_hl = "SplitTyperOk"
  else
    eff_hl = "SplitTyperBad"
  end

  local title_line = {
    { " " .. cat_name, "SplitTyperHeader" },
    { "  ", "" },
    { progress, "SplitTyperProgress" },
  }
  if state.timed_mode then
    title_line[#title_line + 1] = { "  ", "" }
    local remaining = stats.remaining_time
    if not state.start_time then
      remaining = state.timed_duration
    end
    title_line[#title_line + 1] = {
      "Time Left: " .. ctx.state_mod.format_time(remaining),
      remaining <= 10 and "SplitTyperBad" or "SplitTyperOk",
    }
  end
  if state.no_backspace then
    title_line[#title_line + 1] = { "    NO BACKSPACE", "SplitTyperBad" }
  end
  if state.error_limit ~= nil then
    title_line[#title_line + 1] = { "    ", "" }
    title_line[#title_line + 1] = {
      string.format("STRICT ERRORS: %d/%d", stats.errors, state.error_limit),
      stats.errors > state.error_limit and "SplitTyperBad" or (stats.errors == state.error_limit and "SplitTyperOk" or "SplitTyperGood"),
    }
  end

  local stats_line = {
    { " Net WPM: ", "SplitTyperSep" },
    { tostring(stats.wpm), wpm_hl },
    { "  Gross: ", "SplitTyperSep" },
    { tostring(stats.gross_wpm), "SplitTyperStats" },
    { "  Acc: ", "SplitTyperSep" },
    { string.format("%.1f%%", stats.accuracy), acc_hl },
    { "  Eff: ", "SplitTyperSep" },
    { string.format("%.1f%%", stats.efficiency), eff_hl },
    { "  Err: ", "SplitTyperSep" },
    { tostring(stats.errors), stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood" },
    { "  Streak: ", "SplitTyperSep" },
    { tostring(stats.streak), stats.streak >= 10 and "SplitTyperGood" or "SplitTyperStats" },
    { string.format(" (best: %d)", stats.best_streak), "SplitTyperPending" },
  }

  local timer_note = state.start_time
      and " Timer started on first keypress"
      or " Timer starts on first keypress"

  local meta_line = timer_note
  local footer_note = nil
  if state.generated_desc and #state.generated_desc > 0 then
    meta_line = " " .. state.generated_desc
    footer_note = timer_note
  end

  state.header_extmark = vim.api.nvim_buf_set_extmark(state.buf, state.ns, 0, 0, {
    id = state.header_extmark,
    virt_lines_above = true,
    virt_lines = {
      title_line,
      stats_line,
      { { meta_line, "SplitTyperPending" } },
      footer_note and { { footer_note, "SplitTyperPending" } } or { { "", "" } },
      { { " " .. string.rep("\u{2500}", 60), "SplitTyperSep" } },
      { { "", "" } },
    },
  })
end

function M.update_display(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or not state.ns then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  state.header_extmark = nil

  local runs = {}
  for i = 1, #state.char_map do
    local entry = state.char_map[i]
    if entry.is_newline then
      goto continue
    end

    local hl
    if i <= state.pos then
      hl = state.input[i] == entry.char and "SplitTyperCorrect" or "SplitTyperError"
    elseif i == state.pos + 1 then
      hl = "SplitTyperCursor"
    else
      hl = "SplitTyperPending"
    end

    local last = runs[#runs]
    if last and last.line == entry.line and last.hl == hl and last.col_end == entry.col then
      last.col_end = entry.col + 1
    else
      runs[#runs + 1] = {
        line = entry.line,
        col_start = entry.col,
        col_end = entry.col + 1,
        hl = hl,
      }
    end

    ::continue::
  end

  for _, run in ipairs(runs) do
    vim.api.nvim_buf_set_extmark(state.buf, state.ns, run.line, run.col_start, {
      end_col = run.col_end,
      hl_group = run.hl,
    })
  end

  for i = 1, #state.char_map do
    local entry = state.char_map[i]
    if entry.is_newline then
      local hl = "SplitTyperPending"
      local symbol = "\u{21b5}"
      if i <= state.pos then
        if state.input[i] == "\n" then
          hl = "SplitTyperCorrect"
        else
          hl = "SplitTyperError"
        end
      elseif i == state.pos + 1 then
        hl = "SplitTyperEnter"
        symbol = "\u{21b5} Enter"
      end
      vim.api.nvim_buf_set_extmark(state.buf, state.ns, entry.line, entry.col, {
        virt_text = { { " " .. symbol, hl } },
        virt_text_pos = "inline",
      })
    end
  end

  if state.pos < #state.char_map then
    local entry = state.char_map[state.pos + 1]
    local cursor_line = entry.line
    local cursor_col = entry.col
    if entry.is_newline then
      local lines = vim.api.nvim_buf_get_lines(state.buf, entry.line, entry.line + 1, false)
      cursor_col = lines[1] and #lines[1] or 0
    end
    pcall(vim.api.nvim_win_set_cursor, state.win, { cursor_line + 1, cursor_col })
  end

  M.update_stats_header(ctx)
end

return M
