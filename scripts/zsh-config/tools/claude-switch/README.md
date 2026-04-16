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
source ~/.dotfiles/scripts/zsh-config/tools/claude-switch/claude-switch.zsh
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

### CLI switching

```
cs                       Interactive fzf picker to switch CLI profiles
cs go [name]             Switch to a profile (fzf if no name given)
cs ls                    Browse profiles with fzf preview (view-only)
cs add <name>            Create a new empty profile
cs mv <src> <dest>       Rename a profile
cs mv -c <src> <dest>    Clone a profile
cs default [name]        Get or set the auto-loaded default profile
cs default --clear       Remove the default profile
cs help                  Show help
```

Any unrecognised subcommand is treated as a profile name, so `cs work` is the same as `cs go work`.

### Desktop switching

Only one `Claude.app` is needed. Each profile stores a `--user-data-dir` path in a `.desktop-data-dir` file. The primary account has no file (uses the default data dir); secondary accounts each get their own isolated directory. Both instances can run simultaneously.

```
~/.claude-profiles/
  work/
    .claude/
    .claude.json
    # no .desktop-data-dir → opens default Claude.app
  personal/
    .claude/
    .claude.json
    .desktop-data-dir   ← ~/Library/Application Support/Claude-personal
```

```
cs desktop [name]                  Open Claude Desktop for a profile (fzf if no name)
cs desktop set <name> [dir]        Set the data dir (defaults to ~/Library/Application Support/Claude-<name>)
cs desktop set <name> --default    Mark as primary account (no --user-data-dir)
```

**Setup:**

```zsh
cs desktop set work --default   # work uses the default Claude.app data dir
cs desktop set personal         # personal gets ~/Library/Application Support/Claude-personal
```

Then `cs desktop work` focuses the existing work window (or opens it), and `cs desktop personal` spawns a separate personal instance. Both can be open at the same time.
