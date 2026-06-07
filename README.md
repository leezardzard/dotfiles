# dotfiles

macOS dev setup with Zsh, Neovim, and Git worktrees.

## Features

- **macOS bootstrap** — Xcode CLI tools, Homebrew, CLI tools, and casks (iTerm2, VS Code, Docker, etc.)
- **Zsh** — Oh My Zsh, Powerlevel10k, and auto-sourced modular config in `shell/`
- **Shell tools** — bat, eza, zoxide, fzf, fd, atuin, dust, thefuck, tlrc
- **Claude Code** — native CLI install (`~/.local/bin`), kept on PATH automatically
- **Git** — delta pager and **wt** (fzf-based Git worktree switcher)
- **Neovim** — Lazy.nvim, LSP, Telescope, nvim-tree, and more
- **cmux** — pane-layout quick-commands (`cm cd [path] 2..6`), worktree broadcast (`cm wt`), git-aware workspace naming, repo-tracked `cmux.json`
- **Tmux** — configs under `home/`
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
   ./scripts/bootstrap                              # everything
   ./scripts/bootstrap install core node docker     # or a subset
   ./scripts/bootstrap list                         # see categories
   ```

   Package lists live in `scripts/brewfiles/Brewfile.<category>`.

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

To customize the prompt, run `p10k configure`. To add or remove packages, edit the relevant `scripts/brewfiles/Brewfile.<category>` (or `scripts/bootstrap-zshrc.zsh` for shell tools).

## Project structure

```
home/              # Mirrors $HOME; everything here is auto-symlinked into $HOME
  .p10k.zsh        #   -> ~/.p10k.zsh (Powerlevel10k)
  .tmux.conf       #   -> ~/.tmux.conf
  .config/nvim/    #   -> ~/.config/nvim  (Lazy.nvim, plugins, LSP)
  .config/cmux/    #   -> ~/.config/cmux  (pane-layout commands, actions)
  .config/ghostty/ #   -> ~/.config/ghostty (Morandi ANSI palette)
  .claude/statusline-command.sh  # -> ~/.claude/statusline-command.sh
shell/             # Auto-sourced zsh modules (keybindings, tools, dev, git, utilities)
scripts/           # Install-time: bootstrap, Brewfiles, and the dotfile linker
bin/               # Executable helper scripts (e.g. cmux-cd-all)
keyboard/          # Optional Via keymap (e.g. RAMA WORKS KARA)
template/.zshrc    # Base .zshrc copied to ~/.zshrc; shell/load.zsh is prepended
```

Two conventions keep this tidy as it grows: **`home/` mirrors `$HOME`** (drop a
file in, it's linked — no list) and **`shell/` is auto-sourced** (drop a module
in, it loads). See [docs/structure.md](docs/structure.md) for the detailed layout.

## Docs and license

- **Setup and troubleshooting** — [docs/setup.md](docs/setup.md)
- **Features** — [docs/features.md](docs/features.md)
- **License** — [MIT](LICENSE)
- **Contributing** — [CONTRIBUTING.md](CONTRIBUTING.md)
