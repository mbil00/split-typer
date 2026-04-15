# split-typer

A Neovim plugin for practicing touch typing on split keyboards (designed for the ZSA Ergodox EZ with default QWERTY layout).

## Features

- **30 free-play categories**: home row, hand isolation, finger isolation, code snippets, symbols, brackets, precision drills, and more
- **12-level structured course**: progressive key introduction with net-WPM, accuracy, efficiency, and max-error gating
- **Precision mode**: no-backspace exercises that force deliberate typing
- **Strict course mode**: course lessons now disable backspace and require stronger passing streaks
- **Error analysis**: tracks your weakest keys and generates targeted exercises
- **Timed practice**: adaptive 1-5 minute sessions that keep generating fresh text until time runs out
- **Character reaction drill**: 50 one-key prompts for brackets and symbols, with per-hit reaction timing
- **Stats dashboard**: WPM/accuracy trends, best scores, practice streaks, problem key breakdown
- **3,185-word database**: random exercise generation so content never repeats
- **Persistent progress**: course advancement, typing history, and error profiles saved across sessions

## Install

### lazy.nvim

```lua
{
  "mbil00/split-typer",
  cmd = "SplitTyper",
}
```

### Local (development)

```lua
{ dir = "/path/to/split-typer", name = "split-typer" }
```

### Manual

Add to your `init.lua`:

```lua
vim.opt.rtp:prepend("/path/to/split-typer")
```

## Usage

```
:SplitTyper           " Open the main menu
:SplitTyper course    " Jump to the touch typing course
:SplitTyper dashboard " View stats dashboard
:SplitTyper timed     " Open timed practice menu
:SplitTyper reaction  " Open the character reaction drill menu
```

From the menu:
- `[c]` Touch Typing Course
- `[t]` Weak Key Practice (auto-targets your worst keys)
- `[s]` Stats Dashboard
- `[x]` Character Reaction
- `[1-9, 0, a-z]` Free-play categories
- `[q]` Quit

During exercises:
- Type the displayed text character by character
- Characters turn green (correct) or red (error)
- `Enter` for newlines, `Backspace` to correct (disabled in precision mode)
- `Esc` to go back
- Timer starts on the first keypress
- Live net WPM, gross WPM, accuracy, efficiency, error count, and streak counter in the header

## Requirements

- Neovim >= 0.10
