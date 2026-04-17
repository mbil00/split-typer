local M = {}

M.RESULTS_INPUT_COOLDOWN_MS = 2000

function M.build_menu_key_pool(reserved)
  local pool = {}
  for i = 1, 9 do
    pool[#pool + 1] = tostring(i)
  end
  pool[#pool + 1] = "0"
  for ch = string.byte("a"), string.byte("z") do
    local key = string.char(ch)
    if not reserved[key] then
      pool[#pool + 1] = key
    end
  end
  for _, extra in ipairs({ "A", "B", "C", "D", "E" }) do
    pool[#pool + 1] = extra
  end
  return pool
end

function M.render_buffer(state, lines, highlights)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  if state.ns then
    for _, h in ipairs(highlights) do
      pcall(vim.api.nvim_buf_set_extmark, state.buf, state.ns, h[1], h[2], {
        end_col = h[3],
        hl_group = h[4],
      })
    end
  end
end

function M.get_results_lock_remaining_ms(state)
  if not state.results_unlock_at then
    return 0
  end

  return math.max(0, math.ceil((state.results_unlock_at - vim.uv.hrtime()) / 1e6))
end

function M.update_results_lock_hint(ctx)
  local state = ctx.state
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or not state.ns then
    return
  end

  local remaining_ms = M.get_results_lock_remaining_ms(state)
  if remaining_ms <= 0 then
    state.results_unlock_at = nil
    if state.results_lock_extmark then
      pcall(vim.api.nvim_buf_del_extmark, state.buf, state.ns, state.results_lock_extmark)
      state.results_lock_extmark = nil
    end
    return
  end

  local line_count = vim.api.nvim_buf_line_count(state.buf)
  local message = string.format(
    "  Actions unlock in %.1fs to avoid stray keystrokes after the timer ends.",
    remaining_ms / 1000
  )

  state.results_lock_extmark = vim.api.nvim_buf_set_extmark(state.buf, state.ns, line_count - 1, 0, {
    id = state.results_lock_extmark,
    virt_lines = {
      { { "", "" } },
      { { message, "SplitTyperPending" } },
    },
  })
end

function M.start_results_input_lock(ctx)
  local state = ctx.state
  ctx.state_mod.stop_timer(state)
  state.results_unlock_at = vim.uv.hrtime() + (M.RESULTS_INPUT_COOLDOWN_MS * 1e6)
  M.update_results_lock_hint(ctx)

  state.timer = vim.uv.new_timer()
  state.timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      M.update_results_lock_hint(ctx)
      if M.get_results_lock_remaining_ms(state) <= 0 then
        ctx.state_mod.stop_timer(state)
      end
    end)
  )
end

function M.add_results_input_lock_notice(state, lines, highlights)
  local remaining_ms = M.get_results_lock_remaining_ms(state)
  if remaining_ms <= 0 then
    return
  end

  lines[#lines + 1] = ""
  local line = "    Actions are briefly locked to avoid stray keystrokes after the timer ends."
  lines[#lines + 1] = line
  highlights[#highlights + 1] = { #lines - 1, 0, #line, "SplitTyperPending" }
end

function M.map_results_action(ctx, key, fn)
  ctx.window.map(ctx.state, key, function()
    if M.get_results_lock_remaining_ms(ctx.state) > 0 then
      return
    end
    fn()
  end)
end

function M.push_section_separator(lines, highlights, title)
  local label = " \u{2500}\u{2500}\u{2500} " .. title .. " "
  local tail = math.max(3, 50 - vim.fn.strdisplaywidth(label))
  local sep = label .. string.rep("\u{2500}", tail)
  lines[#lines + 1] = sep
  highlights[#highlights + 1] = { #lines - 1, 0, #sep, "SplitTyperSep" }
  lines[#lines + 1] = ""
end

function M.push_menu_entry(lines, highlights, key, name, description)
  local line = string.format("  [%s]  %-28s %s", key, name, description or "")
  lines[#lines + 1] = line
  highlights[#highlights + 1] = { #lines - 1, 2, 5, "SplitTyperMenuKey" }
  highlights[#highlights + 1] = { #lines - 1, 34, #line, "SplitTyperMenuDesc" }
end

function M.push_strictness_header(lines, highlights, state, state_mod)
  local mode = state.strictness or "normal"
  local label = state_mod.strictness_label(mode)
  local hint = state_mod.strictness_hint(mode)
  local line = "       Strictness: " .. label .. "  [.] cycle \u{00B7} " .. hint
  lines[#lines + 1] = line
  highlights[#highlights + 1] = { #lines - 1, 0, #line, "SplitTyperHeader" }
end

return M
