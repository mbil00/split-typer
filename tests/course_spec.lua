local h = require("tests.helpers")

local function pass_stage(course, level_id, stage_id)
  local stage = course.get_stage(level_id, stage_id)
  h.assert_truthy(stage, "stage should exist")
  local passed, stage_cleared, level_complete = course.record_exercise(
    level_id,
    stage_id,
    stage.req_wpm,
    stage.req_accuracy,
    stage.req_efficiency,
    stage.req_max_errors
  )
  return passed, stage_cleared, level_complete
end

return {
  {
    name = "course stages require repeated passes before clearing",
    fn = function()
      h.with_isolated_env("course-reps", function()
        local course = require("split-typer.course")
        course.reset_progress()

        local stage = course.get_stage(1, "single_key")
        h.assert_truthy(stage)
        h.assert_eq(stage.reps_required, 2)

        local passed1, cleared1, level_complete1 = pass_stage(course, 1, "single_key")
        h.assert_eq(passed1, true)
        h.assert_eq(cleared1, false, "first passing run should not clear a 2-rep stage")
        h.assert_eq(level_complete1, false)

        local progress1 = course.get_stage_progress(1, "single_key")
        h.assert_eq(progress1.completed, 1)
        h.assert_eq(progress1.passed, false)

        local passed2, cleared2, level_complete2 = pass_stage(course, 1, "single_key")
        h.assert_eq(passed2, true)
        h.assert_eq(cleared2, true, "second passing run should clear the stage")
        h.assert_eq(level_complete2, false)

        local progress2 = course.get_stage_progress(1, "single_key")
        h.assert_eq(progress2.completed, 2)
        h.assert_eq(progress2.passed, true)
      end)
    end,
  },
  {
    name = "course only unlocks next level after all stages are passed",
    fn = function()
      h.with_isolated_env("course-unlock", function()
        local course = require("split-typer.course")
        course.reset_progress()

        h.assert_eq(course.get_current_level(), 1)
        h.assert_eq(course.is_unlocked(2), false)

        local level_stages = course.get_stage_defs(1)
        for _, stage_def in ipairs(level_stages) do
          local passed1, cleared1, level_complete1 = pass_stage(course, 1, stage_def.id)
          h.assert_eq(passed1, true)
          h.assert_eq(level_complete1, false)
          local passed2, cleared2, level_complete2 = pass_stage(course, 1, stage_def.id)
          h.assert_eq(passed2, true)
          h.assert_eq(cleared2, true)
          if stage_def.id ~= level_stages[#level_stages].id then
            h.assert_eq(level_complete2, false, "level should not complete until the final stage clears")
          end
        end

        local lp = course.get_level_progress(1)
        h.assert_eq(lp.passed, true)
        h.assert_eq(course.get_current_level(), 2, "finishing level 1 should advance current_level")
        h.assert_eq(course.is_unlocked(2), true)
        h.assert_eq(#course.pending_stages(1), 0)
      end)
    end,
  },
  {
    name = "pick_next_stage only returns pending stages until a level is complete",
    fn = function()
      h.with_isolated_env("course-pending", function()
        local course = require("split-typer.course")
        course.reset_progress()

        pass_stage(course, 1, "single_key")
        pass_stage(course, 1, "single_key")

        local pending = course.pending_stages(1)
        h.assert_truthy(#pending > 0)
        local pending_set = {}
        for _, stage_id in ipairs(pending) do
          pending_set[stage_id] = true
        end
        h.assert_eq(pending_set.single_key, nil, "cleared stage should leave the pending set")

        for _ = 1, 20 do
          local next_stage = course.pick_next_stage(1)
          h.assert_truthy(pending_set[next_stage], "pick_next_stage should stay within the pending set")
        end
      end)
    end,
  },
}
