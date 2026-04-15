# split-typer

A Neovim plugin for practicing touch typing on split keyboards, built around the ZSA Ergodox EZ and a standard QWERTY layout.

## Features

- **43 free-play categories** grouped into general drills, characters, code, prose, finger isolation, precision work, and hard accuracy gates
- **12-level course** with progressive key introduction, streak-based passing, no-backspace mode, and max-error thresholds
- **Weak key practice** that uses your saved error profile to bias drills toward your worst characters
- **Timed practice** with adaptive 1-5 minute sessions that keep generating text until the timer expires
- **Combo trainer** with 5 modifier-drill categories for `Ctrl`, `Alt`, numbers, and mixed combinations
- **Character reaction drill** with 4 prompt pools and per-hit reaction timing
- **Strict precision and accuracy modes** including no-backspace drills, one-strike gates, and repeat-until-clean exercises
- **Stats dashboard** with WPM and accuracy trends, best scores, timed-session postmortems, weakest keys, and streak tracking
- **Persistent data** for course progress, session history, and all-time error analysis
- **Randomized content generation** backed by a built-in word database so practice does not collapse into a few fixed prompts

## Install

### lazy.nvim

```lua
{
  "mbil00/split-typer",
  cmd = "SplitTyper",
}
```

### Local development

```lua
{ dir = "/path/to/split-typer", name = "split-typer" }
```

### Manual

Add to your `init.lua`:

```lua
vim.opt.rtp:prepend("/path/to/split-typer")
```

## Usage

```vim
:SplitTyper                   " Open the main menu
:SplitTyper course            " Jump to the touch typing course
:SplitTyper dashboard         " View the stats dashboard
:SplitTyper combos            " Open the combo trainer
:SplitTyper timed             " Open timed practice
:SplitTyper reaction          " Open the reaction-drill menu
:SplitTyper home_row          " Jump to a specific free-play category
:SplitTyper reaction_symbols  " Jump to a specific reaction category
```

The command supports completion for built-in entry points and category IDs.

## Main Menu

- `[c]` Touch Typing Course
- `[t]` Weak Key Practice
- `[s]` Stats Dashboard
- `[k]` Combo Trainer
- `[x]` Character Reaction
- `[d]` Timed Practice
- `[1-9, 0, a-z, A-E]` Free-play categories
- `[q]` Quit

## Exercise Groups

- `General`: home row, left hand, right hand, center column, common words
- `Characters`: numbers, symbols, shifted punctuation, bracket drills
- `Code`: Python, JavaScript, Rust/Go/C, shell and config text
- `Text`: prose paragraphs and mixed challenge prompts
- `Finger Isolation`: per-finger drills plus thumbs and combination work
- `Precision`: no-backspace drills for words, symbols, code, and longer bursts
- `Accuracy`: hard fail gates with explicit error limits and repeat-until-clean behavior

## Modes

### Course

- 12 structured levels that introduce new keys gradually
- Tracks best WPM, best accuracy, completion count, and pass streaks
- Uses no-backspace typing and stricter thresholds than free-play

### Weak Key Practice

- Builds drills from your saved weakest characters
- Falls back to general practice until enough error data has been collected

### Timed Practice

- 1 to 5 minute sessions
- Timer starts on the first keypress
- Text extends automatically as you approach the end of the current chunk
- Results include a timed postmortem with weak keys, weak bigrams, and late-session drift

### Combo Trainer

- 5 categories: `Ctrl + Letter`, `Alt + Letter`, `Ctrl + Number`, `Alt + Number`, `Mixed Modifiers`
- Intended for terminals with reliable modifier reporting
- Useful for split-keyboard shortcut fluency, not just prose typing

### Character Reaction

- 4 categories: letters and digits, brackets, symbols, and code punctuation
- 50 prompts per session
- Tracks accuracy, streaks, and average reaction time

## During Exercises

- Type the displayed text character by character
- Characters turn green when correct and red when incorrect
- `Enter` is used for newline characters
- `Backspace` works in normal free-play and is disabled in precision and course modes
- `Esc` returns to the relevant previous screen
- The header shows live net WPM, gross WPM, accuracy, efficiency, error count, and streaks

## Results And Stats

- Result screens support quick follow-up actions such as next exercise, retry, timed menu, main menu, and stats dashboard
- Session mistakes are summarized by problem keys and common substitutions
- The stats dashboard shows long-term trends, best scores by category, weakest keys, hardest transitions, activity, and practice streaks

## Data Storage

Split Typer stores its persistent data under `stdpath("data") .. "/split-typer"`:

- `progress.json`: course progression
- `history.json`: session history
- `errors.json`: all-time key and bigram error statistics

## Requirements

- Neovim `>= 0.10`
- For the combo trainer, a terminal with reliable modifier-key reporting is strongly recommended
