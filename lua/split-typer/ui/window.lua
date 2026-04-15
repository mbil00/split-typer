local M = {}

function M.setup_highlights()
  local hl = vim.api.nvim_set_hl
  hl(0, "SplitTyperCorrect", { fg = "#a6e3a1", bold = true, default = true })
  hl(0, "SplitTyperError", { fg = "#1e1e2e", bg = "#f38ba8", bold = true, default = true })
  hl(0, "SplitTyperCursor", { bg = "#585b70", underline = true, default = true })
  hl(0, "SplitTyperPending", { fg = "#6c7086", default = true })
  hl(0, "SplitTyperHeader", { fg = "#89b4fa", bold = true, default = true })
  hl(0, "SplitTyperStats", { fg = "#bac2de", default = true })
  hl(0, "SplitTyperGood", { fg = "#a6e3a1", bold = true, default = true })
  hl(0, "SplitTyperOk", { fg = "#f9e2af", bold = true, default = true })
  hl(0, "SplitTyperBad", { fg = "#f38ba8", bold = true, default = true })
  hl(0, "SplitTyperSep", { fg = "#45475a", default = true })
  hl(0, "SplitTyperMenuKey", { fg = "#f9e2af", bold = true, default = true })
  hl(0, "SplitTyperMenuText", { fg = "#cdd6f4", default = true })
  hl(0, "SplitTyperMenuDesc", { fg = "#6c7086", italic = true, default = true })
  hl(0, "SplitTyperTitle", { fg = "#cba6f7", bold = true, default = true })
  hl(0, "SplitTyperEnter", { fg = "#f9e2af", italic = true, default = true })
  hl(0, "SplitTyperScore", { fg = "#f5c2e7", bold = true, default = true })
  hl(0, "SplitTyperProgress", { fg = "#89b4fa", default = true })
  hl(0, "SplitTyperProgressBg", { fg = "#313244", default = true })
end

function M.ensure_window(state, on_cleanup)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    return
  end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "split-typer"
  end

  state.ns = vim.api.nvim_create_namespace("split_typer")

  local width = math.min(math.floor(vim.o.columns * 0.85), 100)
  local height = math.min(math.floor(vim.o.lines * 0.8), 40)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
    title = " Split Typer ",
    title_pos = "center",
  })

  vim.wo[state.win].wrap = true
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = state.buf,
    once = true,
    callback = on_cleanup,
  })
end

function M.cleanup(state, stop_timer)
  stop_timer(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.ns = nil
  state.screen = nil
end

function M.clear_buffer(state)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  if state.ns then
    vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  end
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
end

function M.map(state, key, fn)
  vim.keymap.set("n", key, fn, { buffer = state.buf, nowait = true, silent = true })
  state.mapped_keys[key] = true
end

function M.clear_keymaps(state)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  for key in pairs(state.mapped_keys) do
    pcall(vim.keymap.del, "n", key, { buffer = state.buf })
  end
  state.mapped_keys = {}
end

return M
