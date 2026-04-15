local M = {}

local function display_name(key)
  local names = {
    [" "] = "Space",
    ["\n"] = "Enter",
    ["\t"] = "Tab",
    ["\b"] = "Backspace",
  }
  return names[key] or key
end

function M.setup_keymaps(ctx)
  local state = ctx.state
  local map = ctx.window.map

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
    M.handle_input(ctx, " ")
  end)
  map(state, "<CR>", function()
    M.handle_input(ctx, "\n")
  end)
  map(state, "<Tab>", function()
    M.handle_input(ctx, "\t")
  end)
  map(state, "<BS>", function()
    M.handle_input(ctx, "\b")
  end)
  map(state, "<Esc>", ctx.actions.show_reaction_menu)
  map(state, "<C-c>", ctx.actions.cleanup)

  for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>", "<C-w>" }) do
    map(state, key, function() end)
  end
end

function M.handle_input(ctx, key)
  local state = ctx.state
  if state.finished or state.reaction_waiting then
    return
  end
  if state.reaction_idx < 1 or state.reaction_idx > #state.reaction_prompts then
    return
  end

  local now = vim.uv.hrtime()
  if not state.start_time then
    state.start_time = now
  end

  state.keystroke_count = state.keystroke_count + 1
  local expected = state.reaction_prompts[state.reaction_idx]
  local reaction_start = state.reaction_prompt_started_at or now
  local reaction_ms = (now - reaction_start) / 1e6
  local is_correct = key == expected.key

  state.pos = state.pos + 1
  if is_correct then
    state.correct_count = state.correct_count + 1
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
      actual = key,
      actual_display = display_name(key),
    }
  end

  state.reaction_results[state.reaction_idx] = {
    correct = is_correct,
    actual = key,
    reaction_ms = reaction_ms,
  }
  state.reaction_feedback = {
    correct = is_correct,
    actual_display = display_name(key),
    expected_display = expected.display,
    reaction_ms = math.floor(reaction_ms),
  }
  M.update_display(ctx)

  state.reaction_waiting = true
  local delay = is_correct and 250 or 550
  vim.defer_fn(function()
    state.reaction_waiting = false
    if state.reaction_idx >= #state.reaction_prompts then
      state.finished = true
      state.end_time = vim.uv.hrtime()
      vim.defer_fn(function()
        ctx.save_reaction_stats()
        ctx.actions.show_reaction_results()
      end, 120)
    else
      state.reaction_idx = state.reaction_idx + 1
      state.reaction_feedback = nil
      state.reaction_prompt_started_at = vim.uv.hrtime()
      M.update_display(ctx)
    end
  end, delay)
end

function M.update_display(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or not state.ns then
    return
  end

  local cat = ctx.exercises.get_reaction_category(state.category_id)
  local cat_name = cat and cat.name or "Character Reaction"
  local prompt = state.reaction_prompts[state.reaction_idx]
  local total = #state.reaction_prompts

  local completed = 0
  local correct = 0
  local reaction_total = 0
  for _, result in ipairs(state.reaction_results) do
    completed = completed + 1
    reaction_total = reaction_total + result.reaction_ms
    if result.correct then
      correct = correct + 1
    end
  end
  local avg_ms = completed > 0 and math.floor(reaction_total / completed) or 0

  vim.bo[state.buf].modifiable = true

  local win_width = 80
  pcall(function()
    win_width = vim.api.nvim_win_get_width(state.win)
  end)

  local lines = {}
  local highlights = {}
  lines[#lines + 1] = ""
  lines[#lines + 1] = "       CHARACTER REACTION"
  lines[#lines + 1] = "       " .. cat_name
  lines[#lines + 1] = ""
  highlights[#highlights + 1] = { 1, 0, #lines[2], "SplitTyperTitle" }
  highlights[#highlights + 1] = { 2, 0, #lines[3], "SplitTyperHeader" }
  lines[#lines + 1] = "  Press the shown character as quickly and cleanly as you can."
  lines[#lines + 1] = "  Session length: 50 prompts. Timing starts on the first keypress."
  highlights[#highlights + 1] = { 4, 0, #lines[5], "SplitTyperMenuDesc" }
  highlights[#highlights + 1] = { 5, 0, #lines[6], "SplitTyperMenuDesc" }

  for _ = 1, 3 do
    lines[#lines + 1] = ""
  end

  local display = prompt and prompt.display or "?"
  local target_line_idx = #lines
  if state.reaction_feedback then
    local marker = state.reaction_feedback.correct and "  ✓" or "  ✗"
    local text = display .. marker
    local pad = math.max(0, math.floor((win_width - #text) / 2))
    lines[#lines + 1] = string.rep(" ", pad) .. text
    highlights[#highlights + 1] = {
      target_line_idx,
      pad,
      pad + #text,
      state.reaction_feedback.correct and "SplitTyperGood" or "SplitTyperBad",
    }
    lines[#lines + 1] = ""
    local react = string.format("Reaction: %d ms", state.reaction_feedback.reaction_ms)
    local react_pad = math.max(0, math.floor((win_width - #react) / 2))
    lines[#lines + 1] = string.rep(" ", react_pad) .. react
    highlights[#highlights + 1] = { #lines - 1, react_pad, react_pad + #react, "SplitTyperStats" }
    if not state.reaction_feedback.correct then
      local you_pressed = "You pressed: " .. state.reaction_feedback.actual_display
      local press_pad = math.max(0, math.floor((win_width - #you_pressed) / 2))
      lines[#lines + 1] = string.rep(" ", press_pad) .. you_pressed
      highlights[#highlights + 1] = { #lines - 1, press_pad, press_pad + #you_pressed, "SplitTyperOk" }
    end
  else
    local pad = math.max(0, math.floor((win_width - #display) / 2))
    lines[#lines + 1] = string.rep(" ", pad) .. display
    highlights[#highlights + 1] = { target_line_idx, pad, pad + #display, "SplitTyperTitle" }
  end

  for _ = 1, 4 do
    lines[#lines + 1] = ""
  end

  local bar_width = 30
  local filled = total > 0 and math.floor((completed / total) * bar_width) or 0
  local bar = string.rep("█", filled) .. string.rep("░", bar_width - filled)
  local progress = string.format("       %s  %d / %d", bar, completed, total)
  lines[#lines + 1] = progress
  local progress_line = #lines - 1
  highlights[#highlights + 1] = { progress_line, 7, 7 + filled, "SplitTyperGood" }
  highlights[#highlights + 1] = { progress_line, 7 + filled, 7 + bar_width, "SplitTyperProgressBg" }

  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format(
    "       Correct: %d   Errors: %d   Streak: %d (best %d)   Avg: %d ms",
    correct,
    state.error_count,
    state.streak,
    state.best_streak,
    avg_ms
  )
  highlights[#highlights + 1] = { #lines - 1, 16, 16 + #tostring(correct), "SplitTyperGood" }

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  for _, h in ipairs(highlights) do
    pcall(vim.api.nvim_buf_set_extmark, state.buf, state.ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
    })
  end
end

return M
