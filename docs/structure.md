# Project structure

Directory layout and the conventions that keep it from sprawling.

## Two conventions, no registries

This repo avoids hand-maintained lists. Two filesystem conventions drive everything:

1. **`home/` mirrors `$HOME`.** Anything placed under `home/` at the path it
   should occupy in `$HOME` is symlinked there automatically by
   `scripts/link-dotfiles.zsh` — no list to edit. (`home/.p10k.zsh` → `~/.p10k.zsh`,
   `home/.config/nvim/` → `~/.config/nvim`.)
2. **`shell/` is auto-sourced.** Every `*.zsh` under `shell/` is sourced by
   `shell/load.zsh` on shell start — drop a module in and it loads.

So adding a dotfile or a shell module is a one-file operation; `.gitignore`, the
linker, and the loader all follow the filesystem.

## Repo root

| Path | Description |
|------|-------------|
| `home/` | Mirror of `$HOME`. Everything here is symlinked into `$HOME` by the linker (see below). |
| `shell/` | Modular Zsh runtime config, auto-sourced by `shell/load.zsh`. |
| `scripts/` | Install-time scripts (bootstrap, Brewfiles) and the dotfile linker. |
| `docs/` | This documentation. |
| `bin/` | Executable helper scripts (e.g. `cmux-cd-all`). |
| `keyboard/` | Optional Via keymap (e.g. RAMA WORKS KARA); not installed by scripts. |
| `template/.zshrc` | Base Oh My Zsh `.zshrc`; copied to `~/.zshrc` by bootstrap, then a `source .../shell/load.zsh` line is prepended. |

## `home/` (tracked dotfiles)

Mirrors `$HOME`. The linker walks this tree and links each entry; runtime state
written back through a symlink (logs, caches, `colors.json`) is git-ignored and
skipped — so the link set always equals the tracked set.

| Path | Linked to | Description |
|------|-----------|-------------|
| `home/.p10k.zsh` | `~/.p10k.zsh` | Powerlevel10k config; `p10k configure` writes through the symlink into the repo. |
| `home/.tmux.conf`, `home/.tmux.powerline.conf` | `~/…` | Tmux configs. |
| `home/.config/ghostty/` | `~/.config/ghostty` | Ghostty terminal config — Morandi ANSI 0-15 palette override; affects every CLI tool emitting ANSI 0-15. `cmux reload-config` reloads in place. |
| `home/.config/cmux/` | `~/.config/cmux` | cmux config (`cmux.json` pane layouts + Morandi workspace colors). `colors.json` is the git-ignored persisted repo→color map. |
| `home/.config/nvim/` | `~/.config/nvim` | Neovim config (Lazy.nvim, core, plugins, LSP). |
| `home/.claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude Code status line (four-line "bullet" style; weekly usage via `ccusage`). `bootstrap-zshrc.zsh` rewrites `statusLine.command` in each `settings.json` to a portable `$HOME`-relative path. Runtime deps: `jq`, `ccusage`. |

> **`.config` / `.claude` are linked per-leaf, never whole-dir.** `~/.config` and
> `~/.claude` must stay REAL directories so machine-local entries coexist with the
> repo's links. The linker links each *child* (`~/.config/nvim`, …) and refuses to
> run if `~/.config` is itself a whole-dir symlink into the repo (the historical
> ELOOP cause). These leaf-link dirs are listed in `LEAF_LINK_DIRS` in
> `scripts/link-dotfiles.zsh` — the only knob, and it grows rarely.

## `shell/` (Zsh runtime)

| Path | Description |
|------|-------------|
| `load.zsh` | Entry point. Sources `path.zsh` and `tools/claude.zsh` first (order-sensitive), then auto-globs every other `*.zsh` (alphabetical), then `tools/zoxide.zsh` last. `atuin.zsh` is intentionally skipped — it must load from `~/.zshrc` after Oh My Zsh. |
| `path.zsh` | Prepends `~/.local/bin` to `PATH` (Claude Code native install). Pinned first. |
| `keybindings/bindkey.zsh` | Custom keybindings. |
| `tools/` | Tool configs/aliases: claude, bat, zoxide (`cd`→`z`), eza (`ls`), dust (`df`), atuin, fzf, fd, fzf-git, fzf-preview, thefuck, claude-switch. |
| `development/` | `fnm.zsh` (Node), `go.zsh` (Go). |
| `git/` | `gitconfig` (delta pager; copied to `~/.gitconfig` on first git-delta install) and `worktree.zsh` (**wt** — fzf worktree commands). |
| `utilities/` | `cmux.zsh` (**cm** dispatcher: `cm cd`, `cm wt`, `cm color`) and `ffmpeg.zsh`. |

To add a tool: drop `shell/tools/<name>.zsh` — it auto-loads. Pin it in
`load.zsh` only if its load order matters.

## `scripts/` (install-time)

| Path | Description |
|------|-------------|
| `bootstrap` | System bootstrap orchestrator over per-category Brewfiles (Xcode CLI, Homebrew, packages, casks, mas). |
| `bootstrap-zsh.sh` | Installs zsh, sets default shell, installs Oh My Zsh. |
| `bootstrap-zshrc.zsh` | Powerlevel10k, `.zshrc` setup, shell tools, git-delta + gitconfig, fnm, go, Claude Code; runs `link-dotfiles.zsh apply`, patches each `settings.json` statusLine command, and prepends `source .../shell/load.zsh` to `~/.zshrc`. |
| `link-dotfiles.zsh` | Derives the link set from `home/` and wires it into `$HOME` via idempotent, loop-safe symlinks. `apply` (default) links; `status` reports. No manifest to maintain. |
| `lib/link.zsh` | Linking primitives: `link` (idempotent symlink + backup + same-inode no-op guard), `link_status`, `guard_config_symlink` (refuse to run when `~/.config` is a whole-dir link into a checkout). |
| `brewfiles/` | `Brewfile.<category>` package lists (core, node, cloud, podman, terminal, apps-daily, apps-dev, mas). |
| `setup-supabase` | Bridges `/var/run/docker.sock` to the rootless Podman socket so the Supabase CLI works. Run once after the `podman` category. |
| `utils/homebrew_util.zsh` | `is_package_installed` helper used by bootstrap. |

For a quick feature overview (wt, delta, aliases), see [features.md](features.md).
