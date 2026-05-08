local h = require("tests.helpers")

local function current_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

return {
  {
    name = "opening split-typer creates the floating menu window",
    fn = function()
      h.with_isolated_env("integration-open", function()
        local plugin = require("split-typer")
        local state = require("split-typer.ui.state").state

        plugin.open()

        h.assert_eq(state.screen, "menu")
        h.assert_truthy(state.win and vim.api.nvim_win_is_valid(state.win), "menu should create a valid window")
        h.assert_truthy(state.buf and vim.api.nvim_buf_is_valid(state.buf), "menu should create a valid buffer")
        h.assert_eq(vim.bo[state.buf].filetype, "split-typer")
        h.assert_eq(vim.bo[state.buf].buftype, "nofile")

        local text = current_text(state.buf)
        h.assert_contains(text, "SPLIT TYPER")
        h.assert_contains(text, "Adaptive Touch Typing")
        h.assert_contains(text, "Touch Typing Course")

        h.cleanup_ui()
      end)
    end,
  },
  {
    name = "timed results input lock blocks actions until the cooldown expires",
    fn = function()
      h.with_isolated_env("integration-results-lock", function()
        local common = require("split-typer.ui.screens.common")
        local state_mod = require("split-typer.ui.state")
        local state = state_mod.state
        local buf, win = h.make_visible_buffer()

        state.buf = buf
        state.win = win
        state.ns = vim.api.nvim_create_namespace("split_typer_test_results_lock")

        local triggered = 0
        local ctx = {
          state = state,
          state_mod = state_mod,
          window = {
            map = function(_, _, fn)
              state._mapped_action = fn
            end,
          },
        }

        local old_cooldown = common.RESULTS_INPUT_COOLDOWN_MS
        common.RESULTS_INPUT_COOLDOWN_MS = 120
        common.start_results_input_lock(ctx)
        common.map_results_action(ctx, "n", function()
          triggered = triggered + 1
        end)

        state._mapped_action()
        h.assert_eq(triggered, 0, "action should be blocked while the lock is active")
        h.assert_truthy(common.get_results_lock_remaining_ms(state) > 0)

        vim.wait(400, function()
          return common.get_results_lock_remaining_ms(state) == 0
        end, 20)

        state._mapped_action()
        h.assert_eq(triggered, 1, "action should run after the lock expires")

        common.RESULTS_INPUT_COOLDOWN_MS = old_cooldown
        state_mod.stop_timer(state)
        h.cleanup_ui()
      end)
    end,
  },
  {
    name = "timed session can complete end-to-end and render the timed results screen",
    fn = function()
      h.with_isolated_env("integration-timed-flow", function()
        local plugin = require("split-typer")
        local state = require("split-typer.ui.state").state
        local storage = require("split-typer.storage")

        plugin.open("timed")
        h.assert_eq(state.screen, "timed_menu")

        vim.api.nvim_feedkeys("1", "xt", false)
        vim.wait(300, function()
          return state.screen == "exercise" and state.timed_mode
        end, 20)
        h.assert_eq(state.screen, "exercise")
        h.assert_eq(state.timed_mode, true)

        local function send_char(ch)
          if ch == " " then
            vim.api.nvim_feedkeys(vim.keycode("<Space>"), "xt", false)
          elseif ch == "\n" then
            vim.api.nvim_feedkeys(vim.keycode("<CR>"), "xt", false)
          else
            vim.api.nvim_feedkeys(ch, "xt", false)
          end
        end

        send_char(state.char_map[1].char)
        vim.wait(300, function()
          return state.start_time ~= nil
        end, 20)
        h.assert_truthy(state.start_time ~= nil, "first timed keypress should start the timer")

        state.timed_deadline = vim.uv.hrtime() - 1
        send_char(state.char_map[math.min(2, #state.char_map)].char)

        vim.wait(1400, function()
          return state.screen == "results"
        end, 20)
        h.assert_eq(state.screen, "results")

        local text = current_text(state.buf)
        h.assert_contains(text, "TIMED SESSION COMPLETE")

        local history = storage.read_json(storage.layout_data_path("history"), {})
        h.assert_eq(#history, 1, "timed flow should persist a history entry")
        h.assert_eq(history[1].timed, true)
        h.assert_eq(history[1].mode, "timed")

        h.cleanup_ui()
      end)
    end,
  },
  {
    name = "layout setup is reflected in the rendered main menu",
    fn = function()
      h.with_isolated_env("integration-layout", function()
        local plugin = require("split-typer")
        local state = require("split-typer.ui.state").state

        plugin.setup({ layout = "dvorak" })
        plugin.open()

        local text = current_text(state.buf)
        h.assert_contains(text, "Layout: Dvorak")

        h.cleanup_ui()
      end)
    end,
  },
  {
    name = "dashboard handles corrupt history files by falling back to an empty view",
    fn = function()
      h.with_isolated_env("integration-dashboard-corrupt", function()
        local dashboard = require("split-typer.dashboard")
        local storage = require("split-typer.storage")
        local path = storage.layout_data_path("history")
        vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
        local f = assert(io.open(path, "w"))
        f:write("{ broken history")
        f:close()

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(0, buf)
        local ns = vim.api.nvim_create_namespace("split_typer_test_dashboard_corrupt")
        dashboard.render(buf, ns, vim.api.nvim_get_current_win(), {
          on_back = function() end,
          on_quit = function() end,
          on_reset_errors = function() end,
          map = function() end,
        })

        local text = current_text(buf)
        h.assert_contains(text, "No sessions recorded yet")
        local matches = vim.fn.glob(path .. ".corrupt.*", false, true)
        h.assert_eq(#matches, 1, "dashboard should quarantine corrupt history through storage.read_json")
      end)
    end,
  },
  {
    name = "plugin command opens the requested entry point",
    fn = function()
      h.with_isolated_env("integration-command", function()
        local plugin_files = vim.api.nvim_get_runtime_file("plugin/split-typer.lua", false)
        h.assert_truthy(plugin_files[1], "plugin/split-typer.lua should be discoverable on rtp")
        vim.cmd("source " .. vim.fn.fnameescape(plugin_files[1]))
        vim.cmd("SplitTyper timed")

        local state = require("split-typer.ui.state").state
        h.assert_eq(state.screen, "timed_menu")
        h.assert_truthy(state.win and vim.api.nvim_win_is_valid(state.win))

        local text = current_text(state.buf)
        h.assert_contains(text, "TIMED PRACTICE")

        h.cleanup_ui()
      end)
    end,
  },
}
