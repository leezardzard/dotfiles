# Setup guide

Step-by-step install and what each script does.

## Overview

1. **Clone** the repo to `~/.dotfiles` and `cd` into it.
2. **`./scripts/bootstrap`** — system and Homebrew (Xcode CLI, brew, packages, casks).
3. **`./scripts/bootstrap.zsh`** (or `bootstrap-zsh.sh` then `bootstrap-zshrc.zsh`) — Zsh, Oh My Zsh, theme, tools, and dotfiles wiring.

Optional: symlink Neovim config and use tmux configs as needed.

---

## Step 1: Clone

```shell
git clone https://github.com/leezardzard/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

Use your fork URL if you forked. Replace `https` with `git@github.com:...` if you use SSH.

---

## Step 2: `./scripts/bootstrap`

This script (run once, or re-run to add packages):

1. **Xcode Command Line Tools** — Prompts `xcode-select --install` if not present. Needed for Git and compilers.
2. **Homebrew** — Installs Homebrew if missing, then `brew update` and `brew upgrade`.
3. **CLI packages** — ffmpeg, git, httpie, imagemagick, mas, rename, tree, webkit2png, lerna, awscli, kubernetes-cli, eksctl (Weaveworks tap), btop.
4. **iTerm2 and fonts** — iTerm2 cask, `homebrew/cask-fonts` tap, Hack Nerd Font and Meslo LG Nerd Font (for Powerlevel10k).
5. **Cask apps** — Raycast, Figma, Firefox, GitHub, Chrome, ImageOptim, Notion, Nucleo, Postman, Slack, Rectangle, Spotify, Tor Browser, Transmit, VS Code, ngrok, Robo 3T, Altair GraphQL Client.
6. **Docker** — Docker cask, docker-compose, and CLI plugin symlink under `~/.docker/cli-plugins/`.
7. **Kubernetes / dev** — kubectl, kind; optional `mas install` for Xcode (497799835), Line (539883307), Amphetamine (937984704).

Comment or uncomment lines in `scripts/bootstrap` to skip or add packages (e.g. casks you don’t want).

---

## Step 3: Zsh and shell config

**Option A — Single script (recommended):**

```shell
./scripts/bootstrap.zsh
```

**Option B — Two steps:** install Oh My Zsh first, then config and tools:

```shell
./scripts/bootstrap-zsh.sh   # zsh, chsh, Oh My Zsh
./scripts/bootstrap-zshrc.zsh
```

### What `bootstrap-zshrc.zsh` does

1. **Powerlevel10k** — Clones into Oh My Zsh custom themes if missing.
2. **`.zshrc`** — Backs up existing `~/.zshrc` to `~/.zshrc.backup`, copies `template/.zshrc` to `~/.zshrc`, sets `ZSH_THEME` to Powerlevel10k, then sources it.
3. **Zsh plugins** — Installs and sources zsh-autosuggestions via Homebrew.
4. **Tools** — Installs bat, zoxide, eza, dust, atuin, fzf, fd; clones `fzf-git.sh` to `~/fzf-git.sh` if missing.
5. **Git** — If git-delta not installed: installs it and copies `scripts/zsh-config/git/gitconfig` to `~/.gitconfig` (delta pager only; set `user.name` / `user.email` locally).
6. **Other** — tlrc, thefuck, nvm (+ `~/.nvm`), go.
7. **Bat theme** — Downloads Tokyonight theme and runs `bat cache --build`.
8. **Dotfiles load** — Appends a line to `~/.zshrc`: `source <repo>/scripts/zsh-config/load.zsh`.

After this, new shells load the modular zsh config (keybindings, tools, dev, git worktree `wt`, utilities). Customize the prompt with `p10k configure`.

---

## Optional steps

### Neovim

The repo includes `.config/nvim/` (Lazy.nvim, LSP, Telescope, etc.). To use it:

- **Option 1:** Symlink the directory:
  ```shell
  mkdir -p ~/.config
  ln -sfn ~/.dotfiles/.config/nvim ~/.config/nvim
  ```
- **Option 2:** Set `XDG_CONFIG_HOME` or copy the folder; the above symlink is the usual approach.

### Tmux

Configs are in the repo root: `.tmux.conf` and `.tmux.powerline.conf`. Symlink or copy into `$HOME` if you use tmux:

```shell
ln -sfn ~/.dotfiles/.tmux.conf ~/.tmux.conf
```

### Keyboard (Via)

The `keyboard/` folder contains a RAMA WORKS KARA keymap (e.g. `rama_works_kara.json`). Import or copy into Via as needed; not installed by the scripts.

---

## Troubleshooting

- **`brew: command not found`** — Run step 2 again; ensure Xcode Command Line Tools are installed (`xcode-select --install`) and the script completed the Homebrew install.
- **Default shell is not zsh** — After `bootstrap-zsh.sh`, the script runs `chsh -s $(which zsh)`. Log out and back in (or restart the terminal); verify with `echo $SHELL`.
- **Powerlevel10k / fonts look wrong** — In iTerm2, set the profile font to “MesloLGS NF” (or the Nerd Font you installed). Run `p10k configure` to pick a style.
- **`wt` or other custom commands not found** — Ensure `~/.zshrc` contains the `source .../scripts/zsh-config/load.zsh` line and you’re in zsh; open a new terminal or `source ~/.zshrc`.
- **fzf-git.sh clone fails** — The script uses `git@github.com:...`; if you don’t use SSH, clone manually with HTTPS and put it in `~/fzf-git.sh`, or change the clone URL in `scripts/bootstrap-zshrc.zsh`.

For other issues, open an issue with your macOS version and the exact command and error output (see [CONTRIBUTING.md](../CONTRIBUTING.md)).
