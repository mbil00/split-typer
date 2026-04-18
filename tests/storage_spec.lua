local h = require("tests.helpers")

return {
  {
    name = "storage quarantines corrupt json files",
    fn = function()
      h.with_isolated_env("storage-corrupt", function()
        local storage = require("split-typer.storage")
        local path = storage.data_path("broken.json")
        vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
        local f = assert(io.open(path, "w"))
        f:write("{ definitely not json")
        f:close()

        local value = storage.read_json(path, { ok = true })
        h.assert_eq(value.ok, true, "read_json should return the default on corrupt input")

        local matches = vim.fn.glob(path .. ".corrupt.*", false, true)
        h.assert_eq(#matches, 1, "corrupt file should be preserved with a quarantine suffix")
        h.assert_contains(h.read_file(matches[1]), "definitely not json")
      end)
    end,
  },
  {
    name = "append_capped keeps only the newest entries",
    fn = function()
      h.with_isolated_env("storage-cap", function()
        local storage = require("split-typer.storage")
        local path = storage.data_path("history.json")

        for i = 1, 5 do
          local _, ok = storage.append_capped(path, { idx = i }, 3)
          h.assert_eq(ok, true)
        end

        local items = storage.read_json(path, {})
        h.assert_eq(#items, 3)
        h.assert_eq(items[1].idx, 3)
        h.assert_eq(items[2].idx, 4)
        h.assert_eq(items[3].idx, 5)
      end)
    end,
  },
}
