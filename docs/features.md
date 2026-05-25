# Features

Highlights for adopters: **wt** worktree commands, Git delta, fzf-git, shell aliases, and Neovim config.

## Git worktree: `wt`

The **wt** command is an fzf-based Git worktree switcher (see `scripts/zsh-config/git/worktree.zsh`).

| Command | Description |
|---------|-------------|
| `wt add <branch>` | Add a worktree for a branch (creates the branch if it doesn’t exist). |
| `wt remote` | Fzf-pick a remote branch and add a worktree for it. |
| `wt go` | Fzf-pick a worktree and `cd` into it. |
| `wt wl` | Initialize whitelist: fzf-pick ignored paths from the main worktree and write to `.worktree-sync-whitelist`. |
| `wt sync` | Sync files from the main worktree into the current worktree using `.worktree-sync-whitelist`. |
| `wt rm` | Fzf-pick a worktree (main/dev excluded) and remove it after confirmation. |
| `wt help` | Show usage. |

Examples: `wt add feature-x`, `wt remote`, `wt go`, `wt rm`.

## Git: delta pager

[delta](https://github.com/dandavison/delta) is used as the Git pager for readable diffs (side-by-side, syntax highlighting). Config is in `scripts/zsh-config/git/gitconfig` and is copied to `~/.gitconfig` when git-delta is first installed by the bootstrap. Set `user.name` and `user.email` in your local git config; they are not in the repo.

## fzf and fzf-git

- **fzf** — Fuzzy finder; used by **wt** and by the fzf-git integration.
- **fzf-git.sh** — Cloned to `~/fzf-git.sh` by the bootstrap; provides fuzzy Git workflows (e.g. log, branch, stash) when loaded from the zsh config.

## Shell aliases and tools

| Alias / tool | Description |
|--------------|-------------|
| `cd` → **zoxide** | Smarter `cd` with directory history (`z`). |
| `ls` → **eza** | Modern `ls` with icons. |
| `cat` → **bat** | Syntax-highlighted cat. |
| `df` → **dust** | More readable disk usage. |
| **atuin** | Better shell history (search, sync). |
| **fd** | Fast find; used as a backend for fzf. |
| **thefuck** | Corrects previous command. |
| **tlrc** | Short, practical command help (tldr-style). |

These are wired in `scripts/zsh-config/tools/` and loaded by `load.zsh`.

## cmux pane layouts

The `cm-cd` function (from `scripts/zsh-config/utilities/cmux.zsh`) opens a new cmux workspace with a predefined split layout. All panes inherit the workspace working directory — no per-surface `cd` is needed.

```
cm-cd <2|3|4|5|6> [path]
```

Path defaults to `$PWD`. Path resolution tries a literal path first (with `~` expansion + realpath), then falls back to `zoxide query` — so `cm-cd 4 dotf` finds `~/.dotfiles`. Exits 2 (no workspace created) if the pane count is not in `2..6` or if neither resolution finds a directory.

If the target directory is inside a git repo, the workspace is named `<repo>:<branch>` (repo = basename of the main worktree, so linked worktrees still resolve to the parent repo name) and the description is set to the directory basename. Otherwise the workspace is named after the directory basename.

For `n=2`, `n=3`, and `n=4`, `claude-dev --all` is auto-launched in the right pane (n=2, n=3) or right-top pane (n=4). The other panes start as plain shells.

| n | Geometry | Claude pane |
|---|----------|-------------|
| 2 | Horizontal split 0.5 | right |
| 3 | Horizontal split 0.5: left = 2-stack, right = full-height | right (full-height) |
| 4 | Horizontal split 0.5: left = 2-stack, right = 2-stack (2x2 grid) | right-top |
| 5 | Horizontal split 0.6: left = 2x2 grid, right = full-height side runner | — |
| 6 | Horizontal split 0.5: each side = 3-row via nested verticals (3x2 grid) | — |

Examples:

```shell
cm-cd 4 ~/.dotfiles   # 2x2 grid, claude in right-top, workspace ".dotfiles:main"
cm-cd 3               # 2-left-stack + claude-right, workspace named from $PWD
cm-cd 2 ~/projects/myapp
cm-cd 4 dotf          # zoxide fuzzy match -> ~/.dotfiles
```

The same layouts are available from the cmux command palette as "2 panes" through "6 panes". The workspace `cwd` is set to `.` (the current workspace directory) when invoked from the palette; the palette entries mirror the claude-pane behavior of the function.

`bin/cmux-cd-all <path>` broadcasts `cd <path>` to every terminal surface in the current workspace. The cmux action "cd all panes: ~/.dotfiles" calls this script.

`cm-wt-go` composes the worktree picker (`wt go`) with the pane broadcaster. It fzf-picks a git worktree from `git worktree list`, `cd`s the calling shell into it, runs `cmux-cd-all <path>` so every other pane in the current workspace follows, then renames the cmux workspace to the new `<repo>:<branch>` (matching `cm-cd`'s naming). Outside a cmux workspace it falls back to a local `cd` with a notice; outside a git repo it exits with the same `Not in a git repository.` error as `wt go`.

## Neovim

The repo includes a full Neovim config under `.config/nvim/`:

- **Lazy.nvim** — Plugin manager.
- **LSP** — nvim-lspconfig, Mason.
- **Telescope** — Fuzzy finder.
- **nvim-tree** — File tree.
- **Bufferline**, **lualine**, **treesitter**, **nvim-cmp**, **which-key**, and more.

Symlink `~/.dotfiles/.config/nvim` to `~/.config/nvim` to use it (see [setup.md](setup.md)). No bootstrap script installs Neovim; install it yourself (e.g. `brew install neovim`) and then use this config.
