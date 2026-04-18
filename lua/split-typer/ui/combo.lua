local M = {}

function M.display_name(keymap)
  local inner = keymap:match("^<(.+)>$")
  if inner then
    local parts = {}
    local key = inner
    while true do
      local mod, rest = key:match("^([CASM])%-(.+)$")
      if not mod then
        break
      end
      local mod_names = { C = "Ctrl", A = "Alt", S = "Shift", M = "Meta" }
      parts[#parts + 1] = mod_names[mod] or mod
      key = rest
    end
    if #parts > 0 then
      parts[#parts + 1] = key:upper()
      return table.concat(parts, " + ")
    end
    local specials = { Space = "Space", CR = "Enter", BS = "Backspace", Tab = "Tab" }
    return specials[inner] or inner
  end
  if #keymap == 1 and keymap:match("[A-Z]") then
    return "Shift + " .. keymap
  end
  return keymap
end

function M.setup_keymaps(ctx)
  local state = ctx.state
  local map = ctx.window.map
  local skip_ctrl = { c = true, h = true, i = true, j = true, m = true, q = true, s = true, z = true }

  for ch_code = string.byte("a"), string.byte("z") do
    local ch = string.char(ch_code)
    if not skip_ctrl[ch] then
      local keymap = "<C-" .. ch .. ">"
      map(state, keymap, function()
        M.handle_input(ctx, keymap)
      end)
    end
  end

  for ch_code = string.byte("a"), string.byte("z") do
    local ch = string.char(ch_code)
    local keymap = "<A-" .. ch .. ">"
    map(state, keymap, function()
      M.handle_input(ctx, keymap)
    end)
  end

  for i = 0, 9 do
    local ctrl = "<C-" .. i .. ">"
    local alt = "<A-" .. i .. ">"
    map(state, ctrl, function()
      M.handle_input(ctx, ctrl)
    end)
    map(state, alt, function()
      M.handle_input(ctx, alt)
    end)
  end

  for ch_code = string.byte("a"), string.byte("z") do
    local ch = string.char(ch_code)
    map(state, ch, function()
      M.handle_input(ctx, ch)
    end)
  end
  for ch_code = string.byte("A"), string.byte("Z") do
    local ch = string.char(ch_code)
    map(state, ch, function()
      M.handle_input(ctx, ch)
    end)
  end
  for i = 0, 9 do
    local ch = tostring(i)
    map(state, ch, function()
      M.handle_input(ctx, ch)
    end)
  end

  local specials = "`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/?"
  for i = 1, #specials do
    local c = specials:sub(i, i)
    local lhs = c
    if c == "|" then
      lhs = "<Bar>"
    elseif c == "\\" then
      lhs = "<Bslash>"
    elseif c == "<" then
      lhs = "<lt>"
    end
    map(state, lhs, function()
      M.handle_input(ctx, c)
    end)
  end

  map(state, "<Space>", function()
    M.handle_input(ctx, "<Space>")
  end)
  map(state, "<CR>", function()
    M.handle_input(ctx, "<CR>")
  end)
  map(state, "<BS>", function()
    M.handle_input(ctx, "<BS>")
  end)
  map(state, "<Tab>", function()
    M.handle_input(ctx, "<Tab>")
  end)
  map(state, "<Esc>", ctx.actions.show_combo_menu)
  map(state, "<C-c>", ctx.actions.cleanup)

  for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>", "<C-w>" }) do
    map(state, key, function() end)
  end
end

function M.handle_input(ctx, keymap)
  local state = ctx.state
  if state.finished or state.combo_waiting then
    return
  end
  if state.combo_idx < 1 or state.combo_idx > #state.combos then
    return
  end

  if not state.start_time then
    state.start_time = vim.uv.hrtime()
  end

  local expected = state.combos[state.combo_idx]
  if keymap == "<Space>" and expected.key ~= "<Space>" then
    state.keystroke_count = state.keystroke_count + 1
    state.combo_results[state.combo_idx] = {
      correct = false,
      skipped = true,
      actual = keymap,
    }
    state.combo_feedback = {
      skipped = true,
      actual_display = "Skipped",
      expected_display = expected.display,
    }
    M.update_display(ctx)

    state.combo_waiting = true
    vim.defer_fn(function()
      state.combo_waiting = false
      if state.combo_idx >= #state.combos then
        state.finished = true
        state.end_time = vim.uv.hrtime()
        vim.defer_fn(function()
          ctx.save_combo_stats()
          ctx.actions.show_combo_results()
        end, 200)
      else
        state.combo_idx = state.combo_idx + 1
        state.combo_feedback = nil
        M.update_display(ctx)
      end
    end, 250)
    return
  end

  state.keystroke_count = state.keystroke_count + 1
  local is_correct = keymap == expected.key

  if is_correct then
    state.streak = state.streak + 1
    if state.streak > state.best_streak then
      state.best_streak = state.streak
    end
  else
    state.error_count = state.error_count + 1
    state.streak = 0
    state.error_log[#state.error_log + 1] = {
      expected = expected.key,
      expected_display = expected.display,
      actual = keymap,
      actual_display = M.display_name(keymap),
    }
  end

  state.combo_results[state.combo_idx] = {
    correct = is_correct,
    actual = keymap,
  }
  state.combo_feedback = {
    correct = is_correct,
    actual_display = M.display_name(keymap),
    expected_display = expected.display,
  }
  M.update_display(ctx)

  state.combo_waiting = true
  local delay = is_correct and 350 or 800
  vim.defer_fn(function()
    state.combo_waiting = false
    if state.combo_idx >= #state.combos then
      state.finished = true
      state.end_time = vim.uv.hrtime()
      vim.defer_fn(function()
        ctx.save_combo_stats()
        ctx.actions.show_combo_results()
      end, 200)
    else
      state.combo_idx = state.combo_idx + 1
      state.combo_feedback = nil
      M.update_display(ctx)
    end
  end, delay)
end

function M.update_display(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or not state.ns then
    return
  end

  local cat = ctx.exercises.get_combo_category(state.category_id)
  local cat_name = cat and cat.name or "Combo Trainer"
  local combo = state.combos[state.combo_idx]
  local total = #state.combos

  local completed = 0
  local correct = 0
  for _, result in pairs(state.combo_results) do
    completed = completed + 1
    if result.correct then
      correct = correct + 1
    end
  end

  vim.bo[state.buf].modifiable = true

  local win_width = 80
  pcall(function()
    win_width = vim.api.nvim_win_get_width(state.win)
  end)

  local lines = {}
  local highlights = {}
  for _ = 1, 5 do
    lines[#lines + 1] = ""
  end

  local display = combo.display
  local combo_line_idx = #lines
  if state.combo_feedback then
    if state.combo_feedback.skipped then
      local text = display .. "  skipped"
      local pad = math.max(0, math.floor((win_width - #text) / 2))
      lines[#lines + 1] = string.rep(" ", pad) .. text
      highlights[#highlights + 1] = { combo_line_idx, pad, pad + #text, "SplitTyperPending" }
    elseif state.combo_feedback.correct then
      local text = display .. "  \u{2713}"
      local pad = math.max(0, math.floor((win_width - #text) / 2))
      lines[#lines + 1] = string.rep(" ", pad) .. text
      highlights[#highlights + 1] = { combo_line_idx, pad, pad + #text, "SplitTyperGood" }
    else
      local text = display .. "  \u{2717}"
      local pad = math.max(0, math.floor((win_width - #text) / 2))
      lines[#lines + 1] = string.rep(" ", pad) .. text
      highlights[#highlights + 1] = { combo_line_idx, pad, pad + #text, "SplitTyperBad" }
      lines[#lines + 1] = ""
      local you_pressed = "You pressed: " .. state.combo_feedback.actual_display
      local pad2 = math.max(0, math.floor((win_width - #you_pressed) / 2))
      lines[#lines + 1] = string.rep(" ", pad2) .. you_pressed
      highlights[#highlights + 1] = { #lines - 1, pad2, pad2 + #you_pressed, "SplitTyperOk" }
    end
  else
    local pad = math.max(0, math.floor((win_width - #display) / 2))
    lines[#lines + 1] = string.rep(" ", pad) .. display
    highlights[#highlights + 1] = { combo_line_idx, pad, pad + #display, "SplitTyperTitle" }
  end

  for _ = 1, 4 do
    lines[#lines + 1] = ""
  end

  local bar_width = 30
  local filled = total > 0 and math.floor((completed / total) * bar_width) or 0
  local bar = string.rep("\u{2588}", filled) .. string.rep("\u{2591}", bar_width - filled)
  local progress = string.format("       %s  %d / %d", bar, completed, total)
  lines[#lines + 1] = progress
  local progress_line = #lines - 1
  highlights[#highlights + 1] = { progress_line, 7, 7 + filled, "SplitTyperGood" }
  highlights[#highlights + 1] = { progress_line, 7 + filled, 7 + bar_width, "SplitTyperProgressBg" }

  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format(
    "       Correct: %d   Errors: %d   Streak: %d (best %d)",
    correct,
    state.error_count,
    state.streak,
    state.best_streak
  )

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)

  vim.api.nvim_buf_set_extmark(state.buf, state.ns, 0, 0, {
    virt_lines_above = true,
    virt_lines = {
      { { " " .. cat_name, "SplitTyperHeader" }, { "  ", "" }, { string.format("%d/%d", completed, total), "SplitTyperProgress" } },
      { { " Press the key combination shown below", "SplitTyperMenuDesc" } },
      { { " " .. string.rep("\u{2500}", 60), "SplitTyperSep" } },
      { { "", "" } },
    },
  })

  for _, highlight in ipairs(highlights) do
    pcall(vim.api.nvim_buf_set_extmark, state.buf, state.ns, highlight[1], highlight[2], {
      end_col = highlight[3],
      hl_group = highlight[4],
    })
  end
end

return M
