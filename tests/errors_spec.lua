local h = require("tests.helpers")

local function make_char_map(text)
  return require("split-typer.ui.state").build_char_map(text)
end

return {
  {
    name = "error summaries capture chars, bigrams, trigrams, and transition classes",
    fn = function()
      h.with_isolated_env("errors-summary", function()
        local errors = require("split-typer.errors")
        errors.reset()

        local char_map = make_char_map("fjfjfjfjfj")
        local error_log = {
          { expected = "j", actual = "f", pos = 2 },
          { expected = "j", actual = "f", pos = 4 },
          { expected = "j", actual = "f", pos = 6 },
          { expected = "j", actual = "f", pos = 8 },
          { expected = "j", actual = "f", pos = 10 },
        }
        errors.record_session(error_log, char_map)

        local summary = errors.get_summary()
        h.assert_eq(summary.total_chars, 10)
        h.assert_eq(summary.total_errors, 5)
        h.assert_eq(summary.has_data, false, "single small session should not trip the dashboard data threshold")

        local worst_chars = errors.get_worst_chars(3, 1)
        h.assert_eq(worst_chars[1].char, "j")
        h.assert_eq(worst_chars[1].errors, 5)
        h.assert_truthy((worst_chars[1].confused_with.f or 0) >= 5)

        local worst_bigrams = errors.get_worst_bigrams(3, 1)
        local bigram_set = {}
        for _, item in ipairs(worst_bigrams) do
          bigram_set[item.bigram] = item
        end
        h.assert_truthy(bigram_set.fj or bigram_set.jf, "alternating-session bigrams should be tracked")
        local sample_bigram = bigram_set.fj or bigram_set.jf
        h.assert_truthy(sample_bigram.error_rate > 0)
        h.assert_truthy(vim.tbl_contains(sample_bigram.class_ids, "cross_hand"))

        local worst_trigrams = errors.get_worst_trigrams(3, 1)
        local trigram_set = {}
        for _, item in ipairs(worst_trigrams) do
          trigram_set[item.trigram] = true
        end
        h.assert_truthy(trigram_set.fjf or trigram_set.jfj, "alternating-session trigrams should be tracked")

        local classes = errors.get_worst_transition_classes(8, 1)
        local by_id = {}
        for _, item in ipairs(classes) do
          by_id[item.class_id] = item
        end
        h.assert_truthy(by_id.cross_hand, "transition classes should classify hand alternation")
        h.assert_truthy(by_id.same_finger, "same finger-family transitions should be tracked even across hands")
      end)
    end,
  },
  {
    name = "session worst bigrams respect typed prefix and newline boundaries",
    fn = function()
      h.with_isolated_env("errors-session-bigrams", function()
        local errors = require("split-typer.errors")
        local char_map = make_char_map("ab\ncd")
        local error_log = {
          { expected = "b", actual = "x", pos = 2 },
          { expected = "d", actual = "y", pos = 5 },
        }

        local items = errors.get_session_worst_bigrams(error_log, char_map, 10, 5)
        local by_bigram = {}
        for _, item in ipairs(items) do
          by_bigram[item.bigram] = item
        end

        h.assert_truthy(by_bigram.ab, "ab should be counted before the newline")
        h.assert_truthy(by_bigram.cd, "cd should be counted after the newline")
        h.assert_eq(by_bigram.bc, nil, "newline boundaries should reset bigram tracking")
      end)
    end,
  },
  {
    name = "adaptive focus chars include seed chars plus weak keys and confusions",
    fn = function()
      h.with_isolated_env("errors-focus", function()
        local errors = require("split-typer.errors")
        errors.reset()

        local char_map = make_char_map("aaaaabbbbb")
        local error_log = {
          { expected = "a", actual = "b", pos = 1 },
          { expected = "a", actual = "b", pos = 2 },
          { expected = "a", actual = "b", pos = 3 },
        }
        errors.record_session(error_log, char_map)

        local focus = errors.get_adaptive_focus_chars({
          allowed_chars = "abc",
          seed_chars = "c",
          limit = 3,
          min_total = 1,
        })

        h.assert_match(focus, "^c", "seed chars should stay at the front of adaptive focus output")
        h.assert_truthy(focus:find("a", 1, true) ~= nil, "weak expected chars should be included")
        h.assert_truthy(focus:find("b", 1, true) ~= nil, "common substitutions should be included")
      end)
    end,
  },
}
