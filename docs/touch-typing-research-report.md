# Touch Typing Research Report for Split Typer

## Purpose

This report summarizes what the literature and current teaching practice suggest about teaching touch typing effectively, then translates those findings into concrete product recommendations for `split-typer`.

The focus is not "how to build a typing test." It is "how to teach touch typing so that users become reliably eyes-free, accurate, and eventually fast on a split keyboard, including prose, code, symbols, and real-world transfer."

## Scope and Method

I prioritized:

- Peer-reviewed studies on typing expertise, motor learning, keyboarding instruction, and typing automaticity
- Official or established teaching guidance from Typing.com, TypingClub/edclub, OSHA, and education guidance documents
- Product-relevant implications for adult learners, while also using school-based evidence where it informs sequencing and pacing

I did **not** rely heavily on forum anecdotes. They are useful for color, but too noisy for core design decisions.

## Executive Summary

The strongest conclusion is that touch typing should be treated as a **motor skill acquisition problem**, not just a content sequencing problem.

The most effective teaching flow appears to have these properties:

1. **Sequential, cumulative key introduction**
   New keys should be introduced gradually and reinforced heavily before the learner is asked to perform broad free text.

2. **Accuracy-first progression**
   Speed matters, but early speed-chasing is counterproductive. Progression should be gated primarily by accuracy, consistency, and low visual dependence.

3. **Short, frequent practice**
   Distributed practice beats massed practice. This is one of the most stable findings relevant to keyboard training.

4. **Consistent finger-to-key mapping**
   The evidence suggests that raw speed is not determined only by "using 10 fingers," but by consistent mappings, low hand travel, and anticipatory movement. For teaching, that still argues for a structured touch-typing method.

5. **Transition practice matters more than isolated letter practice after the basics**
   Bottlenecks live in bigrams, same-finger transitions, inward reaches, symbols, and row changes, not just individual keys.

6. **Transfer practice is essential**
   Learners should move from isolated drills to words, phrases, sentences, prose, and code. A course that only teaches lessons is incomplete.

7. **Automaticity lags apparent success**
   Passing a lesson is not the same as being fluent in daily work. Evaluation must include delayed retention and realistic transfer tasks.

8. **Beginners need lower frustration, not only higher strictness**
   Strict no-backspace or first-error-fail modes can be useful, but not as the only default in the earliest phase.

For `split-typer`, the current architecture already aligns well with the literature in several places:

- progressive course
- weak-key practice
- weak-transition practice
- split-boundary drills
- timed practice
- prose/code categories
- layout-aware physical-key training

The main improvement opportunities are:

- make early progression slightly less punitive
- emphasize retention and transfer more explicitly
- treat transitions as a first-class learning target after basic key location is established
- measure hidden dependencies like correction rate, late-session drift, and covered-key transfer rather than only WPM/accuracy

## What the Literature Actually Supports

### 1. Touch typing is a hierarchical motor skill

Typing research consistently models skilled typing as a layered process: a higher-level system selects words and plans text, while a lower-level system executes keystroke sequences. This matters because teaching should not stop at "find the right key." It must build automatic execution of common letter sequences and common movement patterns.

Yamaguchi, Crump, and Logan found that skilled typists can trade speed for accuracy, but most of that trade-off appears to happen in the **inner loop** of keystroke execution rather than in higher-level word planning. In practical terms: once the learner knows what to type, the main constraint is how smoothly and accurately the fingers can carry it out, especially under time pressure.

Implication for `split-typer`:

- Key-location lessons are necessary but insufficient.
- Bigram, trigram, same-finger, cross-center, and symbol-sequence drills are not optional extras. They are the real path to fluency.

### 2. Deliberate structure helps, but sheer accumulated practice also matters

Keith and Ericsson's 2007 study found that typing performance was related both to total typing experience and to more deliberate forms of practice, especially when learners actively pursued typing quickly and had prior formal instruction. A more recent large-sample study of student typists found that high performance was associated with:

- more years of practice
- more time spent typing
- using more fingers
- looking at the keyboard less often

The practical takeaway is nuanced:

- Formal instruction helps.
- Repeated real-world typing helps.
- The best outcome comes when structured instruction is followed by lots of real use.

Implication for the app:

- The course should be the entry point.
- The app should push users from structured lessons into meaningful prose/code work as early as their key map is stable enough.
- "Everyday use" should count as part of the learning model, not as something outside the product.

### 3. Distributed practice is better than massed practice

Baddeley and Longman's classic keyboard training study remains directly relevant. Four groups of postal workers learned to type under different schedules. The most efficient schedule was **one 1-hour session per day**, while the least efficient was **two 2-hour sessions per day**. The authors concluded that keyboard training should be distributed over time rather than massed.

Later teaching guidance says roughly the same thing in more practical classroom terms:

- Typing.com recommends regular short bursts over long training sessions.
- TypingClub recommends at least two or three short sessions per week.
- Nebraska keyboarding guidance recommends brief, frequent instruction and warns that long intensive practice produces diminishing returns.

Implication for the app:

- The product should optimize for 10-30 minute sessions, not marathon grinds.
- Timed practice should probably be used as a focused block, not an endless mode.
- Daily streaks are useful, but "minutes per session" should be capped in recommendations.

### 4. Accuracy first is not a slogan; it is a design principle

This is one of the clearest areas of agreement across sources.

Typing.com explicitly states that accuracy is more important than speed in the beginning and recommends high minimum accuracy targets. TypingClub tells students to focus on accuracy first and treats passing as insufficient compared to full mastery. Nebraska guidance emphasizes technique and accuracy over speed, and recommends delaying formal speed measurement until basic alphabet learning is established in early instruction.

Research on speed-accuracy trade-offs supports this. When typists push speed too early, error rates rise quickly, and much of the resulting performance change comes from degraded low-level motor execution.

Implication for the app:

- Lesson progression should be gated more strongly by accuracy and error quality than by raw speed.
- Correction rate and uncorrected error rate are more informative than gross WPM alone.
- "Mastery" should mean stable high-accuracy performance, not one lucky fast pass.

### 5. What actually predicts faster typing is more specific than "use more fingers"

Feit, Weir, and Oulasvirta's CHI 2016 study is especially useful because it examined modern everyday typists rather than only formally trained typists. Their key finding was not simply that "10 fingers wins." They identified three predictors of high performance:

1. unambiguous finger-to-key mapping
2. active preparation of upcoming keystrokes
3. minimal global hand motion

They also found that self-taught typists can sometimes achieve surprisingly high speeds. Logan, Ulrich, and Lindsey likewise found that nonstandard typists can type fairly automatically, but they perform worse than standard typists when visual guidance is reduced.

This is important for product design because it reframes the target:

- The goal is not rigid orthodoxy for its own sake.
- The goal is **stable, eyes-free, low-motion, predictable movement**.

For a split keyboard app, this is good news. The app can teach a principled movement system without pretending that every expert uses exactly the same micro-technique.

Implication for the app:

- Keep teaching consistent finger assignments by physical key position.
- Focus heavily on eyes-free operation and low-travel movements.
- Use inward index reaches, same-finger transitions, and cross-center movements as explicit skill targets.

### 6. Structured instruction improves outcomes

Several instructional studies support structured keyboarding programs over looser or purely ad hoc practice:

- A 1989 field study reported significant speed improvements across age groups after **ten 45-minute lessons** of touch-typing training.
- A 2013 pilot study in second graders found that daily instruction over eight months improved visual-motor abilities, and typing speed approached handwriting speed for that age.
- A 2018 study comparing instructional methods found that a developmentally structured curriculum outperformed free web-based activity approaches for improving speed, accuracy, and keyboarding method, especially in upper elementary grades.

The precise classroom context differs from adult Neovim users, but the teaching implication travels well:

- Sequence matters.
- Method matters.
- "Just do random tests until you improve" is weak pedagogy.

Implication for the app:

- The course should remain the backbone.
- Free-play drills should be framed as reinforcement and transfer, not the entire teaching system.

### 7. Automaticity takes longer than many learners expect

One of the most useful findings for expectation-setting comes from the higher-education touch-typing studies by Weigelt-Marom and Weintraub. Their work suggests two things:

- a touch-typing instructional program improves keyboarding skills
- immediate post-training gains do not necessarily mean the skill is fully established

In one study, handwriting was still faster than keyboarding immediately after the program, but at a delayed post-test about three months later, keyboarding became faster than handwriting, especially for students with specific learning disabilities.

This matters a lot for user experience. Learners often interpret the early awkward stage as failure. The literature suggests the opposite: the awkward stage is normal, and automation continues to develop after formal instruction ends, especially if the learner keeps using the skill.

Implication for the app:

- The app should tell users that "usable fluency" and "automatic fluency" are different milestones.
- Mastery should include delayed performance checks, not just same-session repetition.

### 8. Touch typing is valuable partly because it reduces visual dependence

This point is easy to miss if the product looks only at WPM.

Standard touch typists outperform nonstandard typists most clearly when visual guidance is reduced. That matters because many real tasks depend on the user looking at:

- source code on screen
- terminal output
- prose they are drafting
- editor navigation state
- paired material in another window

For programmers and terminal users, the value of touch typing is not merely faster speed-test numbers. It is being able to think about the work while the motor system handles the keyboard.

Implication for the app:

- The app should define success as low visual dependence and high attentional freedom.
- Pure speed-test optimization is too narrow.

### 9. Ergonomics and recovery are part of learning quality

OSHA's keyboard guidance is straightforward:

- keyboard directly in front
- shoulders relaxed
- elbows close to the body
- wrists straight and aligned with forearms

OSHA also recommends short micro-breaks and notes that repetitive computer work benefits from recovery pauses.

For split keyboard users, ergonomics is probably even more central than usual, because many of them are already optimizing for comfort and long sessions.

Implication for the app:

- The product should teach posture and break behavior explicitly.
- Performance regressions from fatigue should be treated as learning data, not just "bad sessions."

## Synthesis: What Seems Most Effective

Across the evidence, the most effective touch-typing instruction model looks like this:

1. Teach a stable movement system.
2. Introduce keys sequentially.
3. Keep early sessions short.
4. Reward accuracy, not panic speed.
5. Move quickly from isolated keys to meaningful sequences.
6. Use realistic transfer tasks once core keys are learned.
7. Track weaknesses at the transition level, not only the single-key level.
8. Revisit prior material frequently.
9. Continue real-world use after the course ends.
10. Measure delayed retention and real-task transfer.

That is the model `split-typer` should optimize for.

## Ideal Teaching Flow for Split Typer

This section translates the research into a recommended product flow.

### Phase 0: Onboarding and Baseline

**Goal:** establish starting point, not to shame the learner.

Recommended diagnostics:

- 1-minute visible-key prose baseline
- 1-minute no-backspace baseline
- symbol/bracket baseline
- transition heatmap from first 200-400 keystrokes
- current typing style self-report: touch typist, hybrid, or looking typist

What to tell the learner:

- speed will likely drop at first
- this is normal motor remapping
- success means building reliable movement, not preserving current speed in week one

Product recommendation:

- show baseline in terms of `accuracy`, `correction rate`, `consistency`, and `visual dependence risk`, not only WPM

### Phase 1: Key Map Acquisition

**Goal:** know where keys are and which fingers own them.

This is where your current structured course is strongest.

Recommended practice structure:

- single-key drills
- immediate follow-up bigrams
- small focused words
- short review of previous keys every session

Recommended session length:

- 10-20 minutes for true beginners
- 15-25 minutes for retraining adults

Recommended progression logic:

- prioritize corrected accuracy and low hesitation
- WPM target should be modest
- do not unlock too many new keys per sitting

Important design note:

- For true beginners, fully forbidding backspace across the whole early course is probably too strict.
- TypingClub explicitly recommends allowing corrections for beginners to avoid frustration.
- A better pattern is:
  - `Normal` or soft-correction in earliest exposure
  - `Precision` in consolidation
  - `Accuracy` only for mastery checks

Recommended gate for moving forward:

- corrected accuracy >= 95-97%
- uncorrected accuracy trending upward
- no severe dependence on re-hunting keys
- two successful passes across separate sessions, not just back-to-back

### Phase 2: Sequence Building and Row Completion

**Goal:** turn key knowledge into fluent movement.

This is where many products weaken. Learners know the keys but still type like they are solving a puzzle one letter at a time.

Priority drill types:

- high-frequency bigrams and trigrams
- same-finger transitions
- inward index reaches
- row changes
- center-column and split-boundary patterns
- common word chunks

For split keyboards, this phase is especially important because physical movement patterns differ from standard row-staggered assumptions.

Recommended session mix:

- 30% focused transitions
- 30% focused words
- 20% integration drills over all learned keys
- 20% short prose/code snippets

Recommended gate:

- corrected accuracy >= 96-98%
- repeated weak transitions improving, not just average WPM
- lower correction rate
- stable performance across at least two days

### Phase 3: Transfer to Meaningful Text

**Goal:** move from "can pass lessons" to "can type real things."

This phase should start earlier than many typing tools allow, once the user has enough letter coverage to work with realistic content.

Priority materials:

- plain prose
- editor- or terminal-like commands
- brackets, quotes, underscores, equals, slash, backslash
- code snippets with punctuation density
- numbers and timestamps

Why this matters:

- everyday typing performance differs from isolated lesson performance
- coding and terminal work stress symbols, indentation, repeated punctuation, and mixed alphanumeric patterns

Recommended product behavior:

- as soon as all letters are unlocked, begin mixing in short realistic text every session
- do not wait until the very end to expose learners to real task shapes

### Phase 4: Automaticity and Endurance

**Goal:** sustain good typing without conscious micromanagement.

This phase is less about new content and more about:

- maintaining accuracy at higher speed
- reducing fatigue-related breakdown
- improving performance consistency across 3-5 minute efforts
- handling symbols, code, and context switches cleanly

Priority drills:

- timed prose
- timed code
- weak-transition sessions
- late-session drift analysis
- modifier/shortcut fluency

Metrics that matter here:

- variance across runs
- error bursts late in the session
- correction clusters
- performance gap between simple prose and code punctuation

### Phase 5: Optimization

**Goal:** raise ceiling without sacrificing control.

At this point the learner is already functional. The work becomes more specialized:

- faster look-ahead in prose
- denser symbol sequences
- same-hand and same-finger bottlenecks
- low-frequency but high-cost coding tokens
- keyboard shortcuts and command fluency

This is the right place for:

- aggressive timed practice
- strict no-backspace modes
- higher WPM thresholds
- reaction drills as a supplementary warm-up

It is **not** the right place for beginners.

## Exercise Design Recommendations

### Use isolated-key drills only as a short bridge

Single-key drills are useful at the start of a lesson because they create the basic motor map. They should not dominate the curriculum after that.

Recommended use:

- 1-3 minutes per new key set
- then immediately move into bigrams and meaningful words

### Make transition drills central, not peripheral

The literature points strongly toward low-level movement execution as the bottleneck. Your weak-transition feature is therefore more pedagogically important than it might appear from a feature list.

Recommended transition categories:

- same-finger repeats
- same-hand different-finger patterns
- hand alternation patterns
- inward index transitions
- top-home-bottom row jumps
- symbol-entry patterns
- bracket open-close patterns
- thumb-space rhythm patterns

Recommended drill progression:

1. repeated pair warmup
2. pair embedded in short pseudo-words or real words
3. pair embedded in sentence or code context
4. timed transfer check

### Use focused words, not random gibberish, once the basics are in place

Random letters are useful for exposing raw reach patterns but weak for transfer. Real words and phrase chunks help the learner chunk movement and prepare upcoming keystrokes.

Recommended content ladder:

- focused words heavy in new keys
- common words from the current learned set
- short phrases
- plain sentences
- realistic prose
- realistic code

### Teach symbols later, but not too late

For general writing, symbols can wait until letter control is decent. For coders, symbols cannot be deferred forever.

Recommended sequence:

- letters first
- capitalization/shift
- common punctuation
- brackets and quotes
- number row
- symbol clusters used in code

Important nuance:

- Symbols should be taught in context, not only in walls of punctuation.
- However, isolated symbol reps still help with raw reach and shape familiarity.

### Treat reaction drills as supplementary

Reaction drills can improve alertness and perhaps help with key recognition speed, but touch typing is primarily a **sequence-production skill**, not a simple stimulus-response task.

Recommended role:

- warm-up
- light diagnostic
- variety

Not recommended as:

- main course
- core evidence of mastery

### Use strictness modes strategically

Your three strictness modes are a strong design asset if used intentionally.

Recommended use:

- `Normal`
  - early familiarization
  - realistic transfer practice
  - low-friction repetition

- `Precision`
  - consolidation
  - transition work
  - forcing deliberate clean entry without making one error fatal

- `Accuracy`
  - mastery checks
  - final reps on known material
  - advanced users correcting sloppy habits

Not recommended:

- using `Accuracy` as the default for very early instruction

## Recommended Pacing and Progress Expectations

Precise time-to-speed claims are not strongly supported by the literature, especially for adults retraining existing habits. The evidence is better at supporting **ranges** and **principles** than hard guarantees.

That said, product design still needs realistic expectations.

### What seems reasonable to expect

For adult learners retraining on a split keyboard:

- **First 1-2 weeks:** accuracy and comfort matter more than speed; many users will temporarily become slower than their old hybrid style
- **10-30 hours of structured practice:** many users should become basically usable on core letters if they practice consistently
- **30-60 hours:** many should reach functional touch-typing for general text, though code/symbol fluency will lag
- **months, not days:** high automaticity and strong code punctuation fluency

This is an inference from:

- distributed practice findings
- school keyboarding hour benchmarks
- adult retraining complexity
- research showing delayed post-training gains

It should be framed explicitly as an approximation, not a promise.

### Session recommendations

Recommended practice doses:

- novice adult retraining: 15-25 minutes, 4-6 days/week
- highly motivated user: 20-30 minutes, 5-6 days/week
- avoid repeated 60-120 minute grinding as the default recommendation

Recommended composition of a 20-minute session:

- 3 min review
- 5 min current lesson material
- 5 min transition practice
- 5 min realistic text transfer
- 2 min cool-down or diagnostics

### Progress gates by phase

Suggested product gates for adults:

**Early mapping**

- corrected accuracy >= 95%
- low confusion on new keys
- WPM target intentionally low

**Row completion**

- corrected accuracy >= 96-97%
- uncorrected accuracy no longer collapsing
- same-finger and center-column trouble not severe

**Full-letter unlock**

- corrected accuracy >= 97%
- user can complete short prose without visual panic
- realistic snippets no longer dramatically worse than drills

**Advanced transfer**

- corrected accuracy >= 97-98%
- code and prose within reasonable range of each other
- correction rate manageable
- 3-minute consistency acceptable

## Evaluation Framework

If `split-typer` wants to teach effectively, it should evaluate more than WPM and top-line accuracy.

### Core metrics

- `gross_wpm`
- `net_wpm`
- `corrected_accuracy`
- `uncorrected_accuracy`
- `efficiency`
- `backspaces_per_100_chars`
- `uncorrected_errors_per_100_chars`
- `pause_latency` or hesitation if measurable

### Motor-pattern metrics

- weakest keys
- weakest bigrams
- same-finger error rate
- cross-center error rate
- row-jump error rate
- symbol-sequence error rate
- bracket-pair asymmetry
- left/right imbalance

### Learning-quality metrics

- retention next day
- retention next week
- transfer gap between drills and prose
- transfer gap between prose and code
- late-session drift
- consistency across repeated runs

### Better mastery checks

A stage should not be considered truly mastered based only on two immediate passes. Better mastery logic would include at least one of:

- a delayed pass on a later day
- a transfer pass in slightly different material
- a pass with reduced correction allowance
- stable performance across multiple runs rather than one spike

### Recommended benchmark tests

For product analytics and user feedback, I would keep a small stable benchmark battery:

1. 1-minute core prose
2. 3-minute prose
3. 1-minute symbol/code punctuation
4. 3-minute code-like snippet
5. covered-key or self-declared no-looking mode
6. weak-transition regression test

This gives a far better picture than one generic speed test.

## Accessibility and Differentiation

The literature on learners with dyslexia, learning disabilities, or related writing difficulties suggests touch typing can be beneficial, but the pace and support may need adjustment.

Important design principles:

- keep speed expectations lower initially
- keep accuracy expectations high
- allow more repetition
- use multisensory cues when possible
- measure progress against the learner's baseline, not only population norms
- support realistic accommodations, not just "train harder"

TypingClub and TTRS both emphasize accessibility features. TTRS in particular uses a multisensory approach and notes that some learners need extra time to master keystrokes.

Implication for the app:

- optional slower progression track
- optional audio cue layer if ever added
- lower WPM gates but keep strong accuracy thresholds
- clearer encouragement around delayed automaticity

## Specific Recommendations for Split Typer

### Keep

These parts of the current design are strongly aligned with the evidence:

- physical-key-position course progression
- split-boundary / center-column awareness
- weak-key practice
- weak-transition practice
- layout-aware drills
- code and prose transfer categories
- timed practice with postmortem

### Strengthen

#### 1. Make weak transitions more central in the UI and progression

The literature suggests low-level sequence execution is the bottleneck. Transition drills should become a primary lane after the first core rows are learned, not just a remediation menu.

#### 2. Add delayed mastery checks

Current "clear twice" logic is good, but same-session passes may overestimate learning. A delayed validation pass would better match the research on automaticity and retention.

#### 3. Reconsider no-backspace as universal course behavior

For very early learning, allowing correction may reduce frustration and improve adherence. A better structure is:

- early exposure with correction allowed
- later consolidation with no backspace
- final mastery with stricter rules

#### 4. Use realistic transfer earlier

As soon as enough letters are unlocked, every session should include some realistic text. This will reduce the common complaint that learners can pass lessons but not type real things.

#### 5. Track correction rate and transfer gap explicitly

These are high-value metrics:

- backspaces per 100 chars
- prose-vs-code gap
- drill-vs-transfer gap
- accuracy collapse under longer durations

#### 6. Add phase-aware coaching

The app should tell the user what phase they are in:

- mapping
- stabilization
- transfer
- automaticity
- optimization

That framing would make the learning curve more interpretable.

#### 7. Treat timed practice as a later-stage tool

Timed sessions are important, but they should not become the default too early. They are best once key location is already fairly stable.

### Avoid

- Overweighting raw WPM in the first half of the learning journey
- Treating symbol walls as a substitute for contextual symbol practice
- Assuming that lesson completion equals real-world fluency
- Making the earliest stages too punitive and frustration-heavy
- Measuring only what is easy to log rather than what actually predicts transfer

## Proposed Product-Level Teaching Model

If I were designing the teaching model for this app, I would formalize it like this:

### Stage A: Learn the map

- progressive course
- light correction allowed
- low WPM pressure
- strong technique messaging

### Stage B: Stabilize movement

- bigrams
- focused words
- transition classification
- `Precision` mode

### Stage C: Transfer to real text

- prose
- code
- punctuation in context
- short timed blocks

### Stage D: Build automaticity

- delayed mastery checks
- timed prose and code
- endurance and drift analysis
- reduced visual dependence

### Stage E: Specialize

- symbols
- brackets
- numbers
- combos
- user-specific weak patterns

This structure fits the evidence and fits the plugin's existing architecture.

## Bottom Line

The evidence points toward a clear teaching philosophy:

- Touch typing is best learned as a progressive motor skill.
- Accuracy and consistency should lead speed.
- Short, frequent practice beats long sessions.
- Transition-level drills are where real fluency is built.
- Realistic transfer practice must start early enough.
- Evaluation should measure retention, correction behavior, and prose/code transfer, not only WPM.

`split-typer` is already unusually well-positioned for this because it understands:

- physical key positions
- split-boundary movement
- weak transitions
- code and symbol practice

That gives it the ingredients to become more than a typing toy. With better progression logic, better mastery checks, and stronger transfer-oriented coaching, it could become a genuinely evidence-informed touch-typing trainer for split-keyboard users.

## Sources

### Research literature

- Baddeley, A. D., & Longman, D. J. A. (1978). *The Influence of Length and Frequency of Training Session on the Rate of Learning to Type*. Ergonomics. https://gwern.net/doc/psychology/spaced-repetition/1978-baddeley.pdf
- Feit, A. M., Weir, D., & Oulasvirta, A. (2016). *How We Type: Movement Strategies and Performance in Everyday Typing*. CHI 2016. https://userinterfaces.aalto.fi/how-we-type/resources/HowWeType_CHI16.pdf
- Keith, N., & Ericsson, K. A. (2007). *A Deliberate Practice Account of Typing Proficiency in Everyday Typists*. Journal of Experimental Psychology: Applied. Abstract surfaced via search: https://www.ovid.com/journals/jepap/pdf/10.1037/1076-898x.13.3.135~a-deliberate-practice-account-of-typing-proficiency-in
- Logan, G. D., Ulrich, J. E., & Lindsey, D. R. (2016). *Different (Key) Strokes for Different Folks: How Standard and Nonstandard Typists Balance Fitts' Law and Hick's Law*. PubMed abstract: https://pubmed.ncbi.nlm.nih.gov/27748613/
- Pinet, S., Zielinski, C., Mathy, F., et al. (2022). *Typing expertise in a large student population*. Cognitive Research: Principles and Implications. https://link.springer.com/article/10.1186/s41235-022-00424-3
- Yamaguchi, M., Crump, M. J. C., & Logan, G. D. (2013). *Speed-Accuracy Trade-Off in Skilled Typewriting: Decomposing the Contributions of Hierarchical Control Loops*. https://www.crumplab.com/publications/Crump/files/13701/Yamaguchi%20et%20al.%20-%202013%20-%20Speed%E2%80%93accuracy%20trade-off%20in%20skilled%20typewriting%20D.pdf
- Glencross, D. J., Bluhm, H., & Earl, A. (1989). *A field study report of intensive computer keyboard training with schoolchildren*. ScienceDirect listing and abstract: https://www.sciencedirect.com/science/article/pii/000368708990135X
- Weigelt-Marom, H., & Weintraub, N. (2015). *The effect of a touch-typing program on keyboarding skills of higher education students with and without learning disabilities*. ScienceDirect listing: https://www.sciencedirect.com/science/article/pii/S0891422215001511
- Weigelt-Marom, H., & Weintraub, N. (2018). *Keyboarding versus handwriting speed of higher education students with and without learning disabilities: Does touch-typing assist in narrowing the gap?* ScienceDirect abstract: https://www.sciencedirect.com/science/article/pii/S0360131517302348
- Donica, D. K., et al. (2018). *Keyboarding instruction: Comparison of techniques for improved keyboarding skills in elementary students*. Taylor & Francis listing and abstract: https://www.tandfonline.com/doi/full/10.1080/19411243.2018.1512067
- Chwirka, B., Gurney, B., & Burtner, P. (2002/2013 indexing). *Keyboarding and visual-motor skills in elementary students: a pilot study*. PubMed: https://pubmed.ncbi.nlm.nih.gov/23941148/
- Bisschop, E., et al. (2024). *Typing Fluencies of 12-13-Year-Old Students with Dyslexia and Peers with Typical Development*. Taylor & Francis listing: https://www.tandfonline.com/doi/full/10.1080/10573569.2024.2304758

### Teaching and practitioner guidance

- Typing.com Teacher Guide. https://www.typing.com/en-gb/teacher/resources/learn-to-type/typing-com-teacher-guide.pdf
- Typing.com support: *WPM / Averages Grade Level*. https://support.typing.com/en/articles/9045953
- TypingClub / edclub Grade 12 Typing Handbook. https://www.edclub.com/m/edclubdocs/media/pdf/Grade12_Typing_Handbook.pdf
- TypingClub help: class-wide difficulty and minimum accuracy guidance. https://typing.typingclub.com/docs/class-management/class-settings/adjust-class-difficulty.html
- Nebraska Department of Education: *Building a Strong Foundation: Elementary Keyboarding*. https://www.education.ne.gov/wp-content/uploads/2017/07/buildingstrongfoundation.pdf
- Touch-type Read and Spell (TTRS) official site. https://www.readandspell.com/us and https://www.readandspell.com/us/dyslexia

### Ergonomics

- OSHA Computer Workstations eTool: Keyboards. https://www.osha.gov/etools/computer-workstations/components/keyboards

