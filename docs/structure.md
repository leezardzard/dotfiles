# Project structure

Directory layout and what each part does.

## Repo root

| Path | Description |
|------|-------------|
| `scripts/` | Bootstrap scripts and modular Zsh config. |
| `template/.zshrc` | Base Oh My Zsh `.zshrc`; copied to `~/.zshrc` by bootstrap, then a `source .../load.zsh` line is appended. |
| `.config/nvim/` | Neovim config (Lazy.nvim, core, plugins, LSP); symlink to `~/.config/nvim` to use. |
| `keyboard/` | Optional Via keymap (e.g. RAMA WORKS KARA); not installed by scripts. |
| `.tmux.conf`, `.tmux.powerline.conf` | Tmux configs; symlink or copy into `$HOME` to use. |

## `scripts/`

| Path | Description |
|------|-------------|
| `bootstrap` | System bootstrap: Xcode CLI, Homebrew, CLI packages, casks, Docker, Kubernetes-related tools, mas apps. |
| `bootstrap-zsh.sh` | Installs zsh, sets default shell, installs Oh My Zsh. |
| `bootstrap-zshrc.zsh` | Powerlevel10k, `.zshrc` setup, shell tools (bat, zoxide, eza, dust, atuin, fzf, fd, fzf-git.sh), git-delta + gitconfig, tlrc, thefuck, nvm, go; appends `source .../load.zsh` to `~/.zshrc`. |
| `utils/homebrew_util.zsh` | Helper `is_package_installed` for Homebrew; used by bootstrap. |
| `zsh-config/` | Modular Zsh config; entry point is `load.zsh`. |

## `scripts/zsh-config/`

| Path | Description |
|------|-------------|
| `load.zsh` | Sources keybindings, tools, development, git, and utilities in order. |
| `keybindings/bindkey.zsh` | Custom keybindings. |
| `tools/` | Tool configs and aliases: bat, zoxide (`cd` → `z`), eza (`ls`), dust (`df`), atuin, fzf, fd, fzf-git, fzf-preview, thefuck. |
| `development/go.zsh` | Go environment. |
| `development/nvm.zsh` | NVM (Node) setup. |
| `git/gitconfig` | Delta pager config; copied to `~/.gitconfig` when git-delta is first installed. |
| `git/worktree.zsh` | **wt** — fzf-based Git worktree commands (`wt add`, `wt go`, `wt remote`, `wt sync`, `wt rm`, etc.). |
| `utilities/ffmpeg.zsh` | FFmpeg-related helpers. |

## `.config/nvim/`

| Path | Description |
|------|-------------|
| `init.lua` | Loads `primary.core` and `primary.lazy`. |
| `lua/primary/` | Core options/keymaps and Lazy.nvim plugin spec; plugins live under `lua/primary/plugins/` (LSP, Telescope, nvim-tree, bufferline, etc.). |

For a quick feature overview (wt, delta, aliases), see [features.md](features.md).
