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

## Neovim

The repo includes a full Neovim config under `.config/nvim/`:

- **Lazy.nvim** — Plugin manager.
- **LSP** — nvim-lspconfig, Mason.
- **Telescope** — Fuzzy finder.
- **nvim-tree** — File tree.
- **Bufferline**, **lualine**, **treesitter**, **nvim-cmp**, **which-key**, and more.

Symlink `~/.dotfiles/.config/nvim` to `~/.config/nvim` to use it (see [setup.md](setup.md)). No bootstrap script installs Neovim; install it yourself (e.g. `brew install neovim`) and then use this config.
