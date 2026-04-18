local h = require("tests.helpers")

return {
  {
    name = "extra words reject unsupported non-ASCII tokens",
    fn = function()
      h.with_isolated_env("words-extra", function()
        local words = require("split-typer.words")
        local report = words.set_extra_words({ "ascii", "žluťoučký", "delta" })
        h.assert_eq(report.loaded, 2)
        h.assert_eq(report.skipped_unsupported, 1)

        local custom = words.get_custom_words()
        h.assert_eq(#custom, 2)
        h.assert_eq(custom[1], "ascii")
        h.assert_eq(custom[2], "delta")
      end)
    end,
  },
}
