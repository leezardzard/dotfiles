# dotfiles

macOS dev setup with Zsh, Neovim, and Git worktrees.

## Features

- **macOS bootstrap** — Xcode CLI tools, Homebrew, CLI tools, and casks (iTerm2, VS Code, Docker, etc.)
- **Zsh** — Oh My Zsh, Powerlevel10k, and modular config in `scripts/zsh-config/`
- **Shell tools** — bat, eza, zoxide, fzf, fd, atuin, dust, thefuck, tlrc
- **Git** — delta pager and **wt** (fzf-based Git worktree switcher)
- **Neovim** — Lazy.nvim, LSP, Telescope, nvim-tree, and more
- **Tmux** — configs in repo root
- **Keyboard** — optional RAMA WORKS KARA / Via keymap in `keyboard/`

## Prerequisites

- macOS
- Git (or install Xcode Command Line Tools in step 1)

## Quick start

1. **Clone** (replace with your fork if you prefer):

   ```shell
   git clone https://github.com/leezardzard/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

   Or clone your fork and add this repo as upstream.

2. **Install system and Homebrew packages:**

   ```shell
   ./scripts/bootstrap
   ```

3. **Install Zsh and shell-related packages:**

   Option 1 (single script):

   ```shell
   ./scripts/bootstrap.zsh
   ```

   Option 2 (Oh My Zsh first, then config and tools):

   ```shell
   ./scripts/bootstrap-zsh.sh
   ./scripts/bootstrap-zshrc.zsh
   ```

To customize the prompt, run `p10k configure`. To add or remove packages, edit `scripts/bootstrap` and `scripts/bootstrap-zshrc.zsh`.

## Project structure

```
scripts/           # Bootstrap and zsh-config (keybindings, tools, dev, git, utilities)
template/.zshrc    # Base .zshrc copied to ~/.zshrc; load.zsh is appended
.config/nvim/      # Neovim config (Lazy.nvim, plugins, LSP)
keyboard/          # Optional Via keymap (e.g. RAMA WORKS KARA)
.tmux.conf         # Tmux config
```

See [docs/structure.md](docs/structure.md) for a detailed layout.

## Docs and license

- **Setup and troubleshooting** — [docs/setup.md](docs/setup.md)
- **Features** — [docs/features.md](docs/features.md)
- **License** — [MIT](LICENSE)
- **Contributing** — [CONTRIBUTING.md](CONTRIBUTING.md)
