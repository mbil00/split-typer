# Touch Typing Teaching Roadmap for Split Typer

## Purpose

This roadmap turns the research in [`docs/touch-typing-research-report.md`](./touch-typing-research-report.md) into a concrete implementation sequence for `split-typer`.

It is deliberately product- and codebase-specific. The goal is not to "add more drills." The goal is to make `split-typer` teach touch typing more effectively by improving:

- early learning flow
- transition from drills to real typing
- mastery and retention checks
- coaching and expectations
- metrics that reflect actual skill acquisition

## Product Direction

The product should evolve toward this teaching model:

1. **Learn the map**
2. **Stabilize movement**
3. **Transfer to real text**
4. **Build automaticity**
5. **Specialize for code and split-keyboard fluency**

The current plugin already has strong raw ingredients:

- structured course progression
- strictness modes
- weak-key practice
- weak-transition practice
- timed practice with decay analysis
- code and prose content
- layout-aware physical-key training

The roadmap focuses on turning those pieces into a more coherent teaching system.

## Guiding Priorities

In order of importance:

1. Reduce early frustration without weakening standards
2. Make transition skill a central part of progression
3. Introduce realistic transfer earlier
4. Add delayed mastery and retention checks
5. Improve metrics so the app measures learning quality, not only speed
6. Add phase-aware coaching so users understand where they are

## Constraints From The Current Codebase

These code realities shape the order of work:

- Course progression is persisted in [`lua/split-typer/course.lua`](/home/mbil/Projects/split-typer/lua/split-typer/course.lua) with `PROGRESS_SCHEMA = 2`.
- Session history is append-only and capped in [`lua/split-typer/ui.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui.lua) and [`lua/split-typer/storage.lua`](/home/mbil/Projects/split-typer/lua/split-typer/storage.lua).
- The live typing state already records enough signal for richer metrics: `error_log`, `key_events`, `backspace_count`, `timed_postmortem`, and per-session stats in [`lua/split-typer/ui/state.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/state.lua) and [`lua/split-typer/ui/typing.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/typing.lua).
- Transition classification and targeted generation are already strong in [`lua/split-typer/errors.lua`](/home/mbil/Projects/split-typer/lua/split-typer/errors.lua) and [`lua/split-typer/words.lua`](/home/mbil/Projects/split-typer/lua/split-typer/words.lua).
- Dashboard reporting is centralized in [`lua/split-typer/dashboard.lua`](/home/mbil/Projects/split-typer/lua/split-typer/dashboard.lua).

That means the first roadmap items should prefer:

- gating changes over total rewrites
- metrics additions over new subsystems
- reusing current content generators before creating new lesson frameworks

## Roadmap Overview

### Horizon 1: Improve the course you already have

Target outcome:

- beginners churn less
- course outcomes become more meaningful
- transitions and transfer stop feeling like side modes

### Horizon 2: Add retention and transfer as first-class teaching signals

Target outcome:

- lesson passing correlates better with real-world fluency
- the app distinguishes "can pass drills" from "can actually type"

### Horizon 3: Build a stronger teaching layer around coaching, benchmarks, and specialization

Target outcome:

- users understand what to practice and why
- advanced users can train for code, symbols, and split-keyboard bottlenecks intentionally

## Milestone 1: Early-Phase Friction Reduction

Priority: `P0`

Why first:

- It improves the learning experience immediately.
- It requires only moderate changes.
- It addresses the biggest mismatch between the research and current behavior: the course is currently no-backspace from the start.

### Goals

- Make the earliest phase less punitive
- Keep mastery standards high
- Preserve the existing course structure

### Proposed changes

1. Add **stage-aware correction policy** for the course.
   Early `single_key` and maybe early `bigrams` stages should allow correction.
   Later consolidation and mastery stages should still use no-backspace.

2. Split course strictness into:
   - `learning` passes: correction allowed
   - `mastery` passes: no backspace, tighter gates

3. Adjust messaging so the user sees:
   - "learning rep"
   - "clean rep"
   - "mastery rep"
   instead of a single undifferentiated pass/fail cycle.

4. Make WPM thresholds slightly less dominant in the earliest levels.
   Accuracy and efficiency should remain the main gate.

### Likely file touchpoints

- [`lua/split-typer/course.lua`](/home/mbil/Projects/split-typer/lua/split-typer/course.lua)
- [`lua/split-typer/ui.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui.lua)
- [`lua/split-typer/ui/screens/course.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/course.lua)
- [`lua/split-typer/ui/state.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/state.lua)

### Implementation notes

- Add stage metadata for correction policy rather than hardcoding "course always no-backspace".
- Keep the existing stage layout and stage IDs.
- Avoid introducing a large content rewrite here.

### Acceptance criteria

- Level 1-3 course stages no longer feel like instant punishment for normal beginner correction behavior.
- Mastery stages still require clean, high-accuracy performance.
- Existing progress data either migrates cleanly or resets with an explicit schema bump and rationale.

## Milestone 2: Delayed Mastery Checks

Priority: `P0`

Why second:

- This is the most important teaching-quality upgrade after friction reduction.
- The research strongly suggests same-session passing overestimates real learning.

### Goals

- Separate immediate performance from retained skill
- Stop treating two rapid passes as true mastery

### Proposed changes

1. Add a **delayed validation requirement** for each stage or level.
   Example:
   - user earns local completion today
   - app marks stage as "validated" only after a successful rep on a later day or after a minimum elapsed interval

2. Track:
   - `first_pass_at`
   - `last_pass_at`
   - `validated_at`
   - `validation_runs`

3. Surface the distinction in the UI:
   - `learned`
   - `passed`
   - `validated`

4. Prefer validation on slightly varied material rather than identical text.

### Likely file touchpoints

- [`lua/split-typer/course.lua`](/home/mbil/Projects/split-typer/lua/split-typer/course.lua)
- [`lua/split-typer/ui/screens/course.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/course.lua)
- [`lua/split-typer/ui/screens/results.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/results.lua)

### Data impact

- Requires `PROGRESS_SCHEMA` bump in course progress.
- This is the cleanest point to formalize stage states instead of only `completed` and `passed`.

### Acceptance criteria

- A stage can no longer be fully mastered only by immediate repetition.
- The course screen clearly indicates pending validation work.
- The system remains understandable and not overly bureaucratic.

## Milestone 3: Transition-First Reinforcement Lane

Priority: `P0`

Why here:

- The app already has strong transition analysis and generation.
- The research says this is where real fluency is built.

### Goals

- Promote transition training from remediation to core pedagogy
- Connect course progression to weak-transition practice automatically

### Proposed changes

1. After selected course stages, offer an automatic **transition reinforcement block**.
   Example:
   - finish `bigrams`
   - app offers 60-90 seconds of targeted same-finger or cross-center work

2. Add a lightweight rule in course progression:
   - if one movement class is clearly failing, recommend or require a short targeted drill before retrying mastery

3. Add a `Course Reinforcement` mode that reuses the existing weak-transition generator but ties it to the current lesson.

4. Make the main menu and results screens describe transitions as a core training path, not just a cleanup tool.

### Likely file touchpoints

- [`lua/split-typer/errors.lua`](/home/mbil/Projects/split-typer/lua/split-typer/errors.lua)
- [`lua/split-typer/words.lua`](/home/mbil/Projects/split-typer/lua/split-typer/words.lua)
- [`lua/split-typer/ui.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui.lua)
- [`lua/split-typer/ui/screens/results.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/results.lua)
- [`lua/split-typer/ui/screens/menus.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/menus.lua)

### Acceptance criteria

- A learner who keeps failing due to the same movement pattern gets directed into the right corrective drill automatically.
- Transition practice feels like part of the course, not a separate expert menu.

## Milestone 4: Earlier Transfer to Real Text

Priority: `P1`

Why after the first three:

- It is high value, but it works best once the course and reinforcement loop are less punitive and better at consolidating skill.

### Goals

- Reduce the gap between lesson success and everyday typing
- Expose users earlier to prose, commands, and code-like text

### Proposed changes

1. Add **short transfer reps** inside the course once enough letters are unlocked.
   Examples:
   - simple prose fragment
   - shell-style command
   - bracketed code fragment

2. Add per-level transfer templates based on the currently unlocked character set.

3. Update course flow so a level is not just:
   - single-key
   - bigrams
   - focused words
   - integration
   - mastery

   but also includes:
   - short transfer rep or transfer check

4. Keep transfer snippets short in early use.
   The purpose is exposure and chunking, not endurance.

### Likely file touchpoints

- [`lua/split-typer/course.lua`](/home/mbil/Projects/split-typer/lua/split-typer/course.lua)
- [`lua/split-typer/exercises.lua`](/home/mbil/Projects/split-typer/lua/split-typer/exercises.lua)
- [`lua/split-typer/words.lua`](/home/mbil/Projects/split-typer/lua/split-typer/words.lua)

### Design caution

- Do not dump users into full code paragraphs too early.
- The first transfer content should be short, forgiving, and tightly aligned to the unlocked set.

### Acceptance criteria

- Users encounter realistic text before the very end of the course.
- Transfer performance becomes visible as a distinct part of progress.

## Milestone 5: Better Metrics and History Schema

Priority: `P1`

Why now:

- The app already records enough to compute richer metrics.
- Several later roadmap items depend on those metrics being stored cleanly.

### Goals

- Measure learning quality, not just raw output
- Make the dashboard and results screens reflect actual teaching priorities

### Proposed metrics to add

- `uncorrected_accuracy`
- `corrected_accuracy`
- `backspaces_per_100_chars`
- `uncorrected_errors_per_100_chars`
- `hesitation_count` or pause-derived metric if practical
- `drill_transfer_gap`
- `prose_code_gap`
- `validation_status`

### Proposed changes

1. Expand session history entries beyond the current:
   - WPM
   - gross WPM
   - accuracy
   - efficiency
   - errors
   - backspaces

2. Add versioned history schema so dashboard logic does not depend on ad hoc field presence.

3. Keep history backward compatible by treating missing fields as unknown rather than zero where necessary.

4. Update dashboard summaries and results screens to highlight:
   - correction dependence
   - timed decay
   - prose/code gap
   - transition burden

### Likely file touchpoints

- [`lua/split-typer/ui/state.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/state.lua)
- [`lua/split-typer/ui.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui.lua)
- [`lua/split-typer/dashboard.lua`](/home/mbil/Projects/split-typer/lua/split-typer/dashboard.lua)
- [`lua/split-typer/storage.lua`](/home/mbil/Projects/split-typer/lua/split-typer/storage.lua)

### Acceptance criteria

- A learner who types fast but relies heavily on backspace is no longer misclassified as doing well.
- The dashboard can distinguish clean performance from corrected performance.

## Milestone 6: Benchmarks and Baselines

Priority: `P1`

Why this is not first:

- It is valuable, but better once the core learning loop and metrics are more trustworthy.

### Goals

- Give users a stable way to see long-term progress
- Measure transfer and automaticity explicitly

### Benchmark battery

Recommended fixed tests:

1. 1-minute prose
2. 3-minute prose
3. 1-minute code punctuation
4. 3-minute code-like snippet
5. no-looking or self-declared covered-key benchmark
6. weak-transition regression benchmark

### Proposed changes

1. Add benchmark definitions and a new persistence file, likely:
   - `benchmarks.json`
   - or benchmark entries within `history`

2. Separate benchmark results from normal practice in the dashboard.

3. Add baseline capture during first use or from a dedicated benchmark menu.

### Likely file touchpoints

- [`lua/split-typer/exercises.lua`](/home/mbil/Projects/split-typer/lua/split-typer/exercises.lua)
- [`lua/split-typer/ui.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui.lua)
- [`lua/split-typer/dashboard.lua`](/home/mbil/Projects/split-typer/lua/split-typer/dashboard.lua)
- [`lua/split-typer/ui/screens/menus.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/menus.lua)

### Acceptance criteria

- Users can compare like-for-like performance over time.
- Benchmarks do not pollute ordinary practice stats.

## Milestone 7: Phase-Aware Coaching

Priority: `P1`

Why it matters:

- Research-backed systems are often effective but opaque.
- Users need clear explanations of what they are optimizing for right now.

### Goals

- Tell users what phase they are in
- Give better next-step guidance after each session

### Proposed coaching phases

- `Mapping`
- `Stabilization`
- `Transfer`
- `Automaticity`
- `Optimization`

### Proposed changes

1. Add phase labeling to the course screen and results flow.

2. Add short recommendations such as:
   - "Accuracy is fine; transition errors are blocking progress."
   - "You are passing drills but transfer to code is lagging."
   - "Your speed is acceptable; late-session accuracy is collapsing."

3. Use existing session data first.
   Avoid a heavyweight recommendation engine.

### Likely file touchpoints

- [`lua/split-typer/ui/screens/course.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/course.lua)
- [`lua/split-typer/ui/screens/results.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/results.lua)
- [`lua/split-typer/ui/screens/menus.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/menus.lua)

### Acceptance criteria

- Users receive actionable guidance after sessions without needing to inspect raw stats.
- The language stays concrete and not patronizing.

## Milestone 8: Advanced Symbol, Number, and Code Specialization

Priority: `P2`

Why later:

- This matters most once the main learning flow is strong.
- The current app already has some content here; the gap is polish and better progression.

### Goals

- Support coders and terminal users more directly
- Build advanced fluency for symbols and mixed-content typing

### Proposed changes

1. Reorganize advanced content into tracks:
   - prose fluency
   - code punctuation
   - shell/CLI fluency
   - brackets and delimiters
   - numbers and timestamps
   - shortcut/modifier fluency

2. Add more contextual symbol practice and fewer raw "walls of symbols."

3. Add split-keyboard-specific advanced drills:
   - inward reaches under speed
   - thumb-cluster transitions
   - cross-center symbol entry

### Likely file touchpoints

- [`lua/split-typer/exercises.lua`](/home/mbil/Projects/split-typer/lua/split-typer/exercises.lua)
- [`lua/split-typer/words.lua`](/home/mbil/Projects/split-typer/lua/split-typer/words.lua)
- [`lua/split-typer/ui/screens/menus.lua`](/home/mbil/Projects/split-typer/lua/split-typer/ui/screens/menus.lua)

### Acceptance criteria

- Advanced users can train for specific real tasks instead of only generic speed.

## Recommended Sequencing

If this is turned into implementation work, I would sequence it like this:

1. Milestone 1: Early-phase friction reduction
2. Milestone 2: Delayed mastery checks
3. Milestone 3: Transition-first reinforcement lane
4. Milestone 5: Better metrics and history schema
5. Milestone 4: Earlier transfer to real text
6. Milestone 7: Phase-aware coaching
7. Milestone 6: Benchmarks and baselines
8. Milestone 8: Advanced specialization

Rationale:

- The first three directly improve the core teaching loop.
- Metrics work should happen before heavier coaching and benchmark features.
- Transfer work benefits from improved progression and improved analytics.

## Suggested Issue Breakdown

To turn this into tickets, I would start with these small-to-medium slices:

1. `course: add stage-level correction policy metadata`
2. `course: bump progress schema and add delayed validation state`
3. `results: show learned vs validated stage status`
4. `transitions: add course reinforcement recommendation after failed stages`
5. `metrics: store corrected vs uncorrected performance in history`
6. `dashboard: visualize correction dependence and transfer gaps`
7. `course: add short transfer checks after letter coverage threshold`
8. `coaching: add phase labels and next-step recommendations`
9. `benchmarks: add stable benchmark menu and persistence`

## Risks and Tradeoffs

### Risk: overcomplicating the course

The current course is simple and understandable. Adding too many states can make it feel bureaucratic.

Mitigation:

- expose only a few user-facing labels
- keep internal state richer than the UI

### Risk: schema churn

Progress and history changes can create migration complexity.

Mitigation:

- batch related schema work
- keep old history readable where possible
- be willing to reset course progress only when there is a strong product reason

### Risk: too much coaching text

The plugin runs in a terminal UI. Too much explanation becomes noise quickly.

Mitigation:

- keep coaching to one or two lines
- show only the most actionable recommendation

### Risk: transfer content becomes too hard too early

Badly timed realism can frustrate beginners.

Mitigation:

- start with very short snippets
- gate transfer by unlocked characters and recent accuracy

## Definition of Success

This roadmap is working if it produces these outcomes:

- more users stick with the course past the earliest levels
- stage completion predicts later performance better than it does now
- users improve on realistic prose and code, not just drills
- weak-transition interventions reduce repeated failure patterns
- dashboard data reflects typing quality, not just headline speed

## Recommended First Build

If only one implementation batch is done next, it should include:

1. stage-aware correction policy for the course
2. delayed stage validation
3. transition reinforcement after failed course runs
4. corrected vs uncorrected metrics in history

That batch would produce the highest leverage change to the teaching quality of the app without requiring a full redesign.

