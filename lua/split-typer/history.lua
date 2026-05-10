local exercises = require("split-typer.exercises")

local M = {}

--- Classify a session-history entry's category into a coarse profile used by
--- both the dashboard and the coach. Drill-y course/timed/targeted runs map to
--- "drill"; prose categories to "prose"; code categories to "code"; everything
--- else falls through to "other".
--- @param category_id string|nil
--- @return "prose"|"code"|"drill"|"other"
function M.category_profile(category_id)
  if not category_id or #category_id == 0 then
    return "other"
  end

  if category_id == "prose" then
    return "prose"
  end

  if category_id:match("^code_") or category_id == "mixed" then
    return "code"
  end

  if category_id:match("^course_")
    or category_id == "targeted_practice"
    or category_id == "transition_practice"
    or category_id == "course_transition_reinforcement"
    or category_id:match("^timed_")
  then
    return "drill"
  end

  local cat = exercises.get_category(category_id)
  if cat then
    if cat.group == "code_prose" then
      return cat.id == "prose" and "prose" or "code"
    end
    if cat.group == "advanced" then
      if cat.id == "advanced_prose_fluency" then
        return "prose"
      end
      if cat.id == "advanced_code_punctuation"
        or cat.id == "advanced_shell_cli"
        or cat.id == "advanced_delimiters"
      then
        return "code"
      end
      return "drill"
    end
    if cat.group == "general" or cat.group == "characters" or cat.group == "fingers" or cat.group == "custom" then
      return "drill"
    end
  end

  return "other"
end

--- Read the uncorrected accuracy off a history entry, falling back through
--- older schemas that only stored a single accuracy field.
--- @param item table
--- @return number
function M.uncorrected_accuracy(item)
  return item.uncorrected_accuracy or item.accuracy or 0
end

--- Read the corrected accuracy (efficiency) off a history entry, falling back
--- through older schemas.
--- @param item table
--- @return number
function M.corrected_accuracy(item)
  return item.corrected_accuracy or item.efficiency or item.accuracy or 0
end

return M
