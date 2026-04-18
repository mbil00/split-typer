local h = require("tests.helpers")

return {
  {
    name = "dashboard excludes combo and reaction sessions from WPM trend and average",
    fn = function()
      h.with_isolated_env("dashboard-metrics", function()
        local storage = require("split-typer.storage")
        storage.write_json(storage.layout_data_path("history"), {
          { mode = "typing", category = "home_row", wpm = 40, speed = 40, speed_unit = "wpm", accuracy = 96, score = 200, time = 60, chars = 200 },
          { mode = "combo", category = "combo_ctrl", cpm = 300, speed = 300, speed_unit = "cpm", accuracy = 99, score = 220, time = 60, chars = 20 },
          { mode = "reaction", category = "reaction_symbols", cpm = 180, speed = 180, speed_unit = "cpm", accuracy = 98, score = 210, time = 60, chars = 50 },
        })

        local dashboard = require("split-typer.dashboard")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(0, buf)
        local ns = vim.api.nvim_create_namespace("split_typer_test_dashboard")
        dashboard.render(buf, ns, vim.api.nvim_get_current_win(), {
          on_back = function() end,
          on_quit = function() end,
          on_reset_errors = function() end,
          map = function() end,
        })

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local text = table.concat(lines, "\n")
        h.assert_contains(text, "Avg WPM:       40", "dashboard average should use only typing sessions")
        h.assert_contains(text, "combo_ctrl", "best scores should still include combo entries")
        h.assert_contains(text, "300 CPM", "best scores should render combo speed in CPM")
        h.assert_contains(text, "180 CPM", "best scores should render reaction speed in CPM")
      end)
    end,
  },
}
