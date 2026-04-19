local exercises = require("split-typer.exercises")
local storage = require("split-typer.storage")

local M = {}

local function load_history()
  return storage.read_json(storage.layout_data_path("history"), {})
end

local function average(values)
  if #values == 0 then
    return nil
  end
  local sum = 0
  for _, value in ipairs(values) do
    sum = sum + value
  end
  return sum / #values
end

local function average_pair(a, b)
  if a ~= nil and b ~= nil then
    return (a + b) / 2
  end
  return a or b
end

local function round_delta(value)
  return math.floor(value + (value >= 0 and 0.5 or -0.5))
end

local function phase_highlight(phase)
  if phase == "Mapping" then
    return "SplitTyperOk"
  end
  if phase == "Stabilization" then
    return "SplitTyperHeader"
  end
  if phase == "Transfer" then
    return "SplitTyperGood"
  end
  if phase == "Automaticity" then
    return "SplitTyperScore"
  end
  return "SplitTyperGood"
end

local function profile_label(profile)
  if profile == "code" then
    return "Code"
  end
  if profile == "prose" then
    return "Prose"
  end
  if profile == "drill" then
    return "Drill"
  end
  return "General"
end

local function summarize_profile(history, profile)
  local items = {}
  for _, item in ipairs(history) do
    if M.history_category_profile(item.category) == profile then
      items[#items + 1] = item
    end
  end
  if #items == 0 then
    return nil
  end

  local wpm_values = {}
  local corrected_values = {}
  for _, item in ipairs(items) do
    wpm_values[#wpm_values + 1] = item.wpm or 0
    corrected_values[#corrected_values + 1] = item.corrected_accuracy or item.efficiency or item.accuracy or 0
  end

  return {
    count = #items,
    avg_wpm = average(wpm_values) or 0,
    avg_corrected = average(corrected_values) or 0,
  }
end

local function history_context()
  local history = load_history()
  return {
    prose = summarize_profile(history, "prose"),
    code = summarize_profile(history, "code"),
    drill = summarize_profile(history, "drill"),
  }
end

local function build_course_recommendation(opts)
  local stats = opts.stats
  local stage = opts.stage
  local stage_prog = opts.stage_prog
  local correction_gap = (stats.corrected_accuracy or 100) - (stats.uncorrected_accuracy or stats.accuracy or 100)

  if not opts.passed_exercise then
    if opts.session_transition_focus and opts.session_transition_focus.class_name then
      return {
        line = "    Coach:       Transition errors are blocking this stage; run the reinforcement drill, then retry cleanly",
        hl = "SplitTyperBad",
      }
    end
    if correction_gap >= 4 or (stats.backspaces_per_100_chars or 0) >= 6 then
      return {
        line = "    Coach:       Too much is being repaired on the fly; slow down slightly and make the first strike cleaner",
        hl = "SplitTyperBad",
      }
    end
    if stats.uncorrected_accuracy < stage.req_accuracy then
      return {
        line = "    Coach:       Accuracy is the blocker here, not speed; keep the rhythm calm and stop chasing WPM",
        hl = "SplitTyperBad",
      }
    end
    if stats.wpm < stage.req_wpm then
      return {
        line = "    Coach:       The pattern is mostly there; repeat at a steady rhythm until the gate clears without forcing",
        hl = "SplitTyperOk",
      }
    end
    return {
      line = "    Coach:       Keep the movement simple and repeatable; this stage should pass from control, not a lucky fast rep",
      hl = "SplitTyperOk",
    }
  end

  if stage_prog and stage_prog.passed and not stage_prog.validated then
    return {
      line = opts.validation_ready
          and "    Coach:       Leave this stage alone until later, then clear one more rep to prove retention"
        or "    Coach:       Stop grinding same-session reps here; let the delay work, then come back for validation",
      hl = "SplitTyperScore",
    }
  end

  if opts.level_validated or opts.stage_validated then
    if opts.level_id >= 8 then
      return {
        line = "    Coach:       Retention looks solid; carry this into prose or code soon so the gain transfers outside drills",
        hl = "SplitTyperGood",
      }
    end
    return {
      line = "    Coach:       This movement is sticking now; move on instead of farming extra reps at the same difficulty",
      hl = "SplitTyperGood",
    }
  end

  if stage.course_mode == "guided" then
    return {
      line = "    Coach:       Guided reps are for reliable reaches; corrections are fine, but try to shrink backspaces next run",
      hl = "SplitTyperOk",
    }
  end

  if stage.course_mode == "mastery" then
    return {
      line = "    Coach:       Mastery reps should feel calm and clean; if speed only appears when forcing, back off slightly",
      hl = "SplitTyperOk",
    }
  end

  if opts.level_id >= 8 then
    return {
      line = "    Coach:       Good drill performance; follow it with prose or code soon so the unlocked set transfers cleanly",
      hl = "SplitTyperGood",
    }
  end

  return {
    line = "    Coach:       Clean repetitions matter more than one strong run; make the stage feel routine before moving on",
    hl = "SplitTyperOk",
  }
end

local function build_benchmark_recommendation(opts)
  local stats = opts.stats
  local latest = opts.benchmark_info and opts.benchmark_info.latest or nil
  local baseline = opts.benchmark_info and opts.benchmark_info.first or nil

  if latest and baseline and (latest.wpm or 0) >= (baseline.wpm or 0) + 5 then
    return {
      line = "    Coach:       The baseline is moving; keep the benchmark fixed and use normal practice for the real training work",
      hl = "SplitTyperGood",
    }
  end

  if (stats.corrected_accuracy or 100) < 95 then
    return {
      line = "    Coach:       Treat the benchmark as a check, not a grind; bring corrected accuracy back up before chasing more WPM",
      hl = "SplitTyperBad",
    }
  end

  return {
    line = "    Coach:       Use benchmarks sparingly; tune speed and endurance in normal sessions, then come back to verify the gain",
    hl = "SplitTyperOk",
  }
end

local function build_timed_recommendation(opts)
  local stats = opts.stats
  local decay = opts.decay
  local correction_gap = (stats.corrected_accuracy or 100) - (stats.uncorrected_accuracy or stats.accuracy or 100)

  if decay and (decay.wpm_delta <= -6 or decay.accuracy_delta <= -3 or decay.efficiency_delta <= -4) then
    return {
      line = "    Coach:       Late-session drift is the issue; start a touch slower or shorten the next rep so the finish stays clean",
      hl = "SplitTyperBad",
    }
  end

  if correction_gap >= 4 or (stats.backspaces_per_100_chars or 0) >= 8 then
    return {
      line = "    Coach:       Endurance is being rescued by corrections; hold a pace you can keep clean all the way through",
      hl = "SplitTyperBad",
    }
  end

  return {
    line = "    Coach:       Timed work is an automaticity check; the last minute should look as controlled as the first",
    hl = "SplitTyperOk",
  }
end

local function build_profile_recommendation(opts, profiles)
  local stats = opts.stats
  local profile = M.history_category_profile(opts.category_id)
  local correction_gap = (stats.corrected_accuracy or 100) - (stats.uncorrected_accuracy or stats.accuracy or 100)

  if profile == "code" then
    if profiles.prose then
      local wpm_gap = round_delta(stats.wpm - profiles.prose.avg_wpm)
      local corr_gap = math.floor((stats.corrected_accuracy - profiles.prose.avg_corrected) * 10) / 10
      if wpm_gap <= -8 or corr_gap <= -3 then
        return {
          line = "    Coach:       Code is trailing your prose baseline; spend the next few sessions on real code, not more drills",
          hl = "SplitTyperBad",
        }
      end
    end
    if correction_gap >= 4 or (stats.backspaces_per_100_chars or 0) >= 6 then
      return {
        line = "    Coach:       The line is getting finished with too many repairs; make punctuation and symbols cleaner on first strike",
        hl = "SplitTyperOk",
      }
    end
    return {
      line = "    Coach:       Code transfer looks healthy; keep mixing punctuation-heavy text with prose so the gains stay honest",
      hl = "SplitTyperGood",
    }
  end

  if profile == "prose" then
    if profiles.code and ((profiles.code.avg_wpm <= stats.wpm - 8) or (profiles.code.avg_corrected <= stats.corrected_accuracy - 3)) then
      return {
        line = "    Coach:       Prose is ahead of code overall; keep a few code sessions in the mix so punctuation does not lag",
        hl = "SplitTyperOk",
      }
    end
    if correction_gap >= 4 or (stats.backspaces_per_100_chars or 0) >= 6 then
      return {
        line = "    Coach:       Flow is there, but too much cleanup is happening mid-line; relax the pace until backspaces fall",
        hl = "SplitTyperOk",
      }
    end
    return {
      line = "    Coach:       Prose is a good transfer lane; keep the text varied instead of repeating short easy fragments",
      hl = "SplitTyperGood",
    }
  end

  if profile == "drill" then
    local real_text_wpm = average_pair(profiles.prose and profiles.prose.avg_wpm or nil, profiles.code and profiles.code.avg_wpm or nil)
    local real_text_corr = average_pair(profiles.prose and profiles.prose.avg_corrected or nil, profiles.code and profiles.code.avg_corrected or nil)
    if real_text_wpm and real_text_corr then
      local wpm_gap = round_delta(stats.wpm - real_text_wpm)
      local corr_gap = math.floor((stats.corrected_accuracy - real_text_corr) * 10) / 10
      if wpm_gap >= 10 or corr_gap >= 4 then
        return {
          line = "    Coach:       Drill skill is ahead of real text; the next reps should be prose or code, not more isolated practice",
          hl = "SplitTyperBad",
        }
      end
    end
    if correction_gap >= 4 or (stats.backspaces_per_100_chars or 0) >= 6 then
      return {
        line = "    Coach:       The drill is being saved by corrections; slow down until the first strike is cleaner",
        hl = "SplitTyperOk",
      }
    end
    return {
      line = "    Coach:       Drill performance is transferring reasonably; alternate it with prose or code to keep it honest",
      hl = "SplitTyperGood",
    }
  end

  return {
    line = "    Coach:       Keep accuracy high enough that the first strike stays trustworthy, then let speed follow",
    hl = "SplitTyperOk",
  }
end

function M.history_category_profile(category_id)
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
    if cat.group == "general" or cat.group == "characters" or cat.group == "fingers" or cat.group == "custom" then
      return "drill"
    end
  end

  return "other"
end

function M.get_course_phase(course, level_id, stage)
  local level_prog = course.get_level_progress(level_id)
  if level_prog.validated and level_id >= #course.levels then
    return "Optimization"
  end
  if stage and stage.id == "transfer" then
    return "Transfer"
  end
  if level_prog.passed and not level_prog.validated then
    return "Automaticity"
  end
  if stage and stage.course_mode == "mastery" then
    return "Automaticity"
  end
  if stage and stage.course_mode == "guided" then
    return "Mapping"
  end
  if level_id <= 3 then
    return "Mapping"
  end
  if level_id <= 7 then
    return "Stabilization"
  end
  if level_id <= 10 then
    return "Transfer"
  end
  return "Automaticity"
end

function M.build_course_overview(course, level_id)
  local phase = M.get_course_phase(course, level_id)
  local focus_line
  if phase == "Mapping" then
    focus_line = "  Focus: Guided reps are for finger-to-key mapping; keep corrections purposeful and do not force speed yet."
  elseif phase == "Stabilization" then
    focus_line = "  Focus: Clean runs matter more now; reduce backspace dependence and make common transitions feel routine."
  elseif phase == "Transfer" then
    focus_line = "  Focus: Most letters are unlocked; move skill into mixed text instead of relying on isolated drills only."
  elseif phase == "Automaticity" then
    focus_line = "  Focus: Treat this as a retention check; delayed validation should confirm the pattern still feels easy later."
  else
    focus_line = "  Focus: Use benchmarks, prose, and code to tune endurance and specialization without giving back accuracy."
  end

  return {
    phase = phase,
    phase_line = "  Current phase: " .. phase,
    phase_hl = phase_highlight(phase),
    recommendation_line = focus_line,
    recommendation_hl = "SplitTyperMenuDesc",
  }
end

function M.build_session_coaching(opts)
  local phase
  local context = nil

  if opts.course and opts.level_id and opts.stage then
    phase = M.get_course_phase(opts.course, opts.level_id, opts.stage)
    context = opts.stage.name
  elseif opts.benchmark_id then
    phase = "Optimization"
    context = "Benchmark"
  elseif opts.timed_mode then
    phase = "Automaticity"
    context = "Timed session"
  else
    local profile = M.history_category_profile(opts.category_id)
    if profile == "code" or profile == "prose" then
      phase = "Transfer"
    elseif profile == "drill" then
      phase = "Stabilization"
    else
      phase = "Stabilization"
    end
    context = profile_label(profile) .. " session"
  end

  local recommendation
  if opts.course and opts.level_id and opts.stage then
    recommendation = build_course_recommendation(opts)
  elseif opts.benchmark_id then
    recommendation = build_benchmark_recommendation(opts)
  elseif opts.timed_mode then
    recommendation = build_timed_recommendation(opts)
  else
    local profiles = history_context()
    if M.history_category_profile(opts.category_id) == "drill" and (profiles.prose or profiles.code) then
      phase = "Transfer"
    end
    recommendation = build_profile_recommendation(opts, profiles)
  end

  return {
    phase = phase,
    phase_line = string.format("    Phase:       %s  |  %s", phase, context or "Session"),
    phase_hl = phase_highlight(phase),
    recommendation_line = recommendation.line,
    recommendation_hl = recommendation.hl,
  }
end

return M
