local h = require("tests.helpers")

local function with_ui_env(label, fn)
  h.with_isolated_env(label, function(root)
    local _ = root
    local buf, win = h.make_visible_buffer()
    local ok, err = pcall(fn, buf, win)
    h.cleanup_ui()
    vim.api.nvim_set_current_win(win)
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    if not ok then
      error(err, 0)
    end
  end)
end

return {
  {
    name = "restart preserves targeted practice semantics and metadata",
    fn = function()
      with_ui_env("ui-targeted-retry", function()
        local state_mod = require("split-typer.ui.state")
        local ui = require("split-typer.ui")
        local state = state_mod.state

        state.strictness = "accuracy"
        ui.start_targeted_exercise()
        local original_target = state.target
        local original_desc = state.generated_desc
        h.assert_truthy(original_desc and #original_desc > 0, "targeted sessions should keep a focus description")
        h.assert_eq(state.no_backspace, false, "weak-key sessions should ignore strictness")
        h.assert_eq(state.repeat_until_clean, false)

        ui.restart_current_text()

        h.assert_eq(state.target, original_target, "retry should keep the same prompt")
        h.assert_eq(state.generated_desc, original_desc, "retry should preserve the generated description")
        h.assert_eq(state.no_backspace, false, "retry should preserve original typing rules")
        h.assert_eq(state.repeat_until_clean, false)
      end)
    end,
  },
  {
    name = "restart preserves transition practice semantics and selected class",
    fn = function()
      with_ui_env("ui-transition-retry", function()
        local state_mod = require("split-typer.ui.state")
        local ui = require("split-typer.ui")
        local state = state_mod.state

        state.strictness = "accuracy"
        ui.start_transition_exercise("same_hand")
        local original_target = state.target
        local original_desc = state.generated_desc

        h.assert_eq(state.transition_focus_class, "same_hand")
        h.assert_eq(state.no_backspace, false, "transition sessions should ignore strictness")

        ui.restart_current_text()

        h.assert_eq(state.target, original_target, "retry should keep the same transition prompt")
        h.assert_eq(state.generated_desc, original_desc, "retry should preserve transition description")
        h.assert_eq(state.transition_focus_class, "same_hand", "retry should preserve selected transition class")
        h.assert_eq(state.no_backspace, false)
      end)
    end,
  },
  {
    name = "combo space skip advances without counting as an error",
    fn = function()
      with_ui_env("ui-combo-skip", function(buf, win)
        local combo = require("split-typer.ui.combo")
        local state_mod = require("split-typer.ui.state")
        local state = state_mod.state

        state_mod.reset_combo_session(state, "combo_ctrl", {
          { display = "Ctrl + A", key = "<C-a>" },
        })
        state.buf = buf
        state.win = win
        state.ns = vim.api.nvim_create_namespace("split_typer_test_combo")

        local saved = false
        local shown = false
        local ctx = {
          state = state,
          save_combo_stats = function()
            saved = true
          end,
          actions = {
            show_combo_results = function()
              shown = true
            end,
            cleanup = function() end,
            show_combo_menu = function() end,
          },
          exercises = {
            get_combo_category = function()
              return { name = "Combo Trainer" }
            end,
          },
        }

        combo.handle_input(ctx, "<Space>")
        vim.wait(1000, function()
          return saved and shown and state.finished
        end, 20)

        local stats = state_mod.get_combo_stats(state)
        h.assert_eq(stats.skipped, 1, "space skip should count as skipped")
        h.assert_eq(stats.errors, 0, "space skip should not count as an error")
        h.assert_eq(stats.correct, 0)
      end)
    end,
  },
}
