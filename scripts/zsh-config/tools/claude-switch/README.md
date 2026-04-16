# claude-switch

A lightweight Zsh tool for managing and switching between multiple [Claude Code](https://claude.ai/code) profiles. Each profile keeps its own credentials (`~/.claude.json`) and config directory (`CLAUDE_CONFIG_DIR`), letting you seamlessly switch between, for example, a personal and a work account.

## How it works

Claude Code stores credentials in `~/.claude.json` and config in the directory pointed to by `CLAUDE_CONFIG_DIR`. `claude-switch` manages a directory of profile slots at `~/.claude-profiles/`, each containing their own copies of those files. Switching a profile replaces the `~/.claude.json` symlink and sets `CLAUDE_CONFIG_DIR` for the current shell session.

```
~/.claude-profiles/
  personal/
    .claude/          ← CLAUDE_CONFIG_DIR for this profile
    .claude.json      ← symlinked to ~/.claude.json when active
  work/
    .claude/
    .claude.json
```

## Requirements

- [fzf](https://github.com/junegunn/fzf) — for the interactive picker (`brew install fzf`)

## Setup

Source `claude-switch.zsh` in your shell config (already wired up via `scripts/zsh-config/load.zsh` in this dotfiles repo):

```zsh
source ~/.dotfiles/claude-switch/claude-switch.zsh
```

### Migrate an existing account

```zsh
cs add personal
cp ~/.claude.json ~/.claude-profiles/personal/.claude.json
cp -r ~/.claude/* ~/.claude-profiles/personal/.claude/
cs personal
```

Then repeat `cs add <name>` and sign in to Claude Code for each additional account.

### Set a default profile

```zsh
cs default personal   # auto-loaded on every new terminal
```

## Usage

```
cs                    Interactive fzf picker to switch profiles
cs go [name]          Switch to a profile (fzf if no name given)
cs ls                 Browse profiles with fzf preview (view-only)
cs add <name>         Create a new empty profile
cs mv <src> <dest>    Rename a profile
cs mv -c <src> <dest> Clone a profile
cs default [name]     Get or set the auto-loaded default profile
cs default --clear    Remove the default profile
cs help               Show help
```

Any unrecognised subcommand is treated as a profile name, so `cs work` is the same as `cs go work`.
