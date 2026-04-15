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

  if not state.start_time then
    state.start_time = vim.uv.hrtime()
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

  if state.pos >= #state.char_map then
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

  M.update_display(ctx)
end

function M.handle_backspace(ctx)
  local state = ctx.state
  if state.finished or state.pos <= 0 then
    return
  end

  state.keystroke_count = state.keystroke_count + 1
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
  local progress = string.format("%d/%d", state.pos, #state.char_map)

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

  local title_line = {
    { " " .. cat_name, "SplitTyperHeader" },
    { "  ", "" },
    { progress, "SplitTyperProgress" },
  }
  if state.no_backspace then
    title_line[#title_line + 1] = { "    NO BACKSPACE", "SplitTyperBad" }
  end

  local stats_line = {
    { " WPM: ", "SplitTyperSep" },
    { tostring(stats.wpm), wpm_hl },
    { "  Acc: ", "SplitTyperSep" },
    { string.format("%.1f%%", stats.accuracy), acc_hl },
    { "  Err: ", "SplitTyperSep" },
    { tostring(stats.errors), stats.errors > 0 and "SplitTyperBad" or "SplitTyperGood" },
    { "  Streak: ", "SplitTyperSep" },
    { tostring(stats.streak), stats.streak >= 10 and "SplitTyperGood" or "SplitTyperStats" },
    { string.format(" (best: %d)", stats.best_streak), "SplitTyperPending" },
  }

  state.header_extmark = vim.api.nvim_buf_set_extmark(state.buf, state.ns, 0, 0, {
    id = state.header_extmark,
    virt_lines_above = true,
    virt_lines = {
      title_line,
      stats_line,
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
