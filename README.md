# split-typer

A Neovim plugin for adaptive touch-typing practice, with split-keyboard-aware drills. Works on QWERTY and Dvorak out of the box; exercises are driven by physical key position, so adding another layout is a one-file addition.

## Features

- **Free-play drills organized into 4 groups** — General, Characters, Code & Prose, and Fingers — so the main menu stays readable
- **12-level course** with progressive key introduction, streak-based passing, no-backspace mode, and max-error thresholds
- **Layout-aware drills** — physical categories (home row, finger isolation, course levels, cross-center detection) adapt to QWERTY or Dvorak based on your config; content categories (code, prose, symbols) stay glyph-stable across layouts
- **Weak key practice** that uses your saved error profile to bias drills toward your worst characters
- **Weak transition practice** that targets your hardest letter-to-letter movements with warmups and adaptive word drills
- **Movement classification** that highlights same-finger, cross-center, symbol, and number-row trouble patterns
- **Timed practice** with adaptive 1-5 minute sessions that keep generating text until the timer expires
- **Combo trainer** with 5 modifier-drill categories for `Ctrl`, `Alt`, numbers, and mixed combinations
- **Character reaction drill** with 4 prompt pools and per-hit reaction timing
- **Strictness mode** applied to any free-play drill: cycle `Normal` → `Precision` (no backspace) → `Accuracy` (no backspace, first-error fail, repeat until clean) with a single keystroke
- **Stats dashboard** with WPM and accuracy trends, best scores, timed-session postmortems, weakest keys, and streak tracking
- **Persistent data** for course progress, session history, and all-time error analysis; isolated per layout so switching layouts does not pollute stats
- **Randomized content generation** backed by a built-in word database so practice does not collapse into a few fixed prompts
- **Custom word lists** — point the plugin at your own vocabulary and get a dedicated Custom Words category plus extra words mixed into general drills

## Install

### lazy.nvim

```lua
{
  "mbil00/split-typer",
  cmd = "SplitTyper",
  -- Optional: pick a keyboard layout. Defaults to QWERTY.
  opts = { layout = "dvorak" },
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
:SplitTyper transitions       " Open weak-transition practice
:SplitTyper combos            " Open the combo trainer
:SplitTyper timed             " Open timed practice
:SplitTyper reaction          " Open the reaction-drill menu
:SplitTyper fingers           " Jump straight to a free-play group submenu
:SplitTyper home_row          " Jump to a specific free-play category
:SplitTyper reaction_symbols  " Jump to a specific reaction category
```

The command supports completion for built-in entry points, group ids, and category ids.

## Main Menu

- `[c]` Touch Typing Course
- `[t]` Weak Key Practice
- `[w]` Weak Transitions
- `[d]` Timed Practice
- `[k]` Combo Trainer
- `[x]` Character Reaction
- `[s]` Stats Dashboard
- `[1]` General drills submenu
- `[2]` Characters submenu
- `[3]` Code & Prose submenu
- `[4]` Fingers submenu
- `[5]` Custom Words submenu (shown only when configured)
- `[.]` Cycle strictness (Normal / Precision / Accuracy)
- `[q]` Quit

Submenus show a short list of the categories in that group; hit a key to launch, `Esc` to return.

## Free-play Groups

- **General**: home row, left hand, right hand, center column, common words
- **Characters**: numbers, isolated brackets, bracket context, isolated symbols, symbol context
- **Code & Prose**: Python, JavaScript, Rust/Go/C, shell & config, prose paragraphs, ultimate challenge
- **Fingers**: 8 per-column drills plus thumbs and finger-combination work
- **Custom Words**: drills drawn exclusively from your configured list (hidden until configured)

## Modes

### Strictness (Normal / Precision / Accuracy)

Strictness is a persistent mode applied to every free-play drill you launch. Cycle it with `.` from the main menu or any group submenu — the header always shows the active mode.

- `Normal`: backspace allowed, no error cap
- `Precision`: no backspace, no error cap — think before you type
- `Accuracy`: no backspace, first-error fail, repeat until clean

Course, Weak Key, Weak Transition, and Timed sessions keep their own rules and ignore the strictness toggle.

### Course

- 12 structured levels that introduce new keys gradually
- Tracks best WPM, best accuracy, completion count, and pass streaks
- Uses no-backspace typing and stricter thresholds than free-play

### Weak Key Practice

- Builds drills from your saved weakest characters
- Falls back to general practice until enough error data has been collected

### Weak Transition Practice

- Builds drills from your saved hardest bigrams
- Labels those failures by movement type, such as same-finger or cross-center transitions
- Prioritizes the single weakest movement class first, then selects bigrams from that class
- Uses class-specific drill shapes, such as tighter repeats for same-finger work or more line-break/space rhythm for thumb-cluster work
- Mixes in small class-specific template banks, such as code punctuation for symbol jumps or short line-break patterns for thumb work
- Starts with short repeated warmups, then shifts into adaptive word drills
- Falls back to weak-key or general practice until enough transition data has been collected

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
- `Backspace` works in Normal strictness and is disabled in Precision/Accuracy strictness and course mode
- `Esc` returns to the relevant previous screen
- The header shows live net WPM, gross WPM, accuracy, efficiency, error count, and streaks

## Results And Stats

- Result screens support quick follow-up actions such as next exercise, retry, timed menu, main menu, and stats dashboard
- Session mistakes are summarized by problem keys and common substitutions
- The stats dashboard shows long-term trends, best scores by category, weakest keys, hardest transitions, activity, and practice streaks
- The dashboard also highlights difficult transition chains so you can spot repeated movement failures, not just single-key misses
- Weak transitions are grouped into movement types so you can see whether the problem is hand alternation, same-finger repeats, symbol jumps, or center-column crossings

## Keyboard Layouts

Split Typer treats exercises as driven by physical key position, not glyph. Ship a layout definition (a grid of glyphs over the columnar 3×10 + number row) and every physical drill — home row, left/right hand, center column, finger isolation, course levels, cross-center transition detection — resolves correctly for that layout.

Built-in layouts: `qwerty` (default), `dvorak`, and `colemak-dh`. Configure via `setup`:

```lua
require("split-typer").setup({ layout = "dvorak" })
```

Content categories (prose, code, brackets, symbols, numbers) do **not** adapt — they drill the same glyphs regardless of layout, because the code you type is the same, only the key positions under your fingers change.

### Custom Layouts

Pass a layout table directly to `setup` instead of a built-in id. The table is validated at load time and you'll get a specific error message if any field is wrong (wrong length, bad `hand`/`finger`/`row` enum, non-string glyph, etc.).

```lua
require("split-typer").setup({
  layout = {
    id = "my-colemak",          -- unique id, used for the per-layout data files
    display_name = "My Colemak", -- shown in the menu header
    rows = {
      -- Each row is exactly 10 single-character strings, left to right.
      -- Column 1 = left pinky, 5 = left index inward, 6 = right index inward, 10 = right pinky.
      number = { "1","2","3","4","5","6","7","8","9","0" },
      top    = { "q","w","f","p","b","j","l","u","y",";" },
      home   = { "a","r","s","t","g","m","n","e","i","o" },
      bottom = { "z","x","c","d","v","k","h",",",".","/" },
    },
    -- 10 single-character strings, one per column (shift of the number row).
    shifted_number_row = { "!","@","#","$","%","^","&","*","(",")" },
    -- Extra glyphs that live outside the 3x10 letter grid (right-pinky reaches
    -- like `[`, `]`, `-`, `=`, their shifted forms, and any shifts of letter-grid
    -- punctuation that don't fall out of the lowercase-uppercase mapping).
    -- `hand` ∈ left|right|thumbs, `finger` ∈ pinky|ring|middle|index|number|thumb,
    -- `row` ∈ outer|inner|center|number|thumb.
    extras = {
      { chars = { "[","]","'","-","=","\\" },
        hand = "right", finger = "pinky", row = "outer" },
      { chars = { "{","}","\"","_","+","|" },
        hand = "right", finger = "pinky", row = "outer" },
    },
  },
})
```

The shipped layout files in `lua/split-typer/layouts/` (`qwerty.lua`, `dvorak.lua`, `colemak_dh.lua`) are the reference implementations to copy from.

### Limitations

- Finger assignments target columnar split keyboards (Corne, Kyria, Ergodox, Sofle, etc.). On row-staggered boards the number row in particular will feel slightly off.
- Shifted-symbol positions assume a standard US base. Layouts that remap those (programmer Dvorak, international variants) need their own `shifted_number_row` and `extras` entries — the schema supports it.

## Custom Words

Point the plugin at your own vocabulary — domain-specific terms, a personal frequency list, words you keep mistyping, etc. Two effects:

1. The words are **merged into the built-in pool**, so they appear inside normal drills whenever their characters fit the drill's allowed set.
2. A new **Custom Words** free-play category appears in the menu that draws *only* from your list.

Configure via `setup`:

```lua
-- From a file (one word per line, or whitespace-separated; comments are not stripped)
require("split-typer").setup({
  extra_words = "~/.config/split-typer/my-words.txt",
})

-- Or inline as a Lua table
require("split-typer").setup({
  extra_words = { "kubectl", "terraform", "nginx", "postgres", "systemd" },
})
```

Notes:

- The Custom Words category is hidden from the menu until you configure a non-empty list, so default installs stay unchanged.
- Words that include characters outside a drill's allowed set are simply skipped for that drill — for example, `home_row` still only surfaces words typable on home keys, even after merging.
- There is no implicit lowercasing. If you want your words to participate in home-row or finger drills, keep them lowercase; uppercase or non-ASCII entries will only appear in Custom Words and any drill whose character set includes them.

## Data Storage

Split Typer stores its persistent data under `stdpath("data") .. "/split-typer"`:

- `progress.json`: course progression
- `history.json`: session history
- `errors.json`: all-time key, transition, and movement-class error statistics

Non-default layouts use suffixed filenames (e.g. `errors.dvorak.json`, `progress.dvorak.json`) so each layout's stats stay isolated. The un-suffixed QWERTY files are unchanged for existing users.

## Requirements

- Neovim `>= 0.10`
- For the combo trainer, a terminal with reliable modifier-key reporting is strongly recommended
