# Setup guide

Step-by-step install and what each script does.

## Overview

1. **Clone** the repo to `~/.dotfiles` and `cd` into it.
2. **`./scripts/bootstrap`** — system and Homebrew (Xcode CLI, brew, packages, casks). Backed by per-category Brewfiles in `scripts/brewfiles/`.
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

The bootstrap script is a thin orchestrator over per-category Brewfiles in `scripts/brewfiles/`. It supports subcommands so you can install everything, install only what you need, or upgrade later — without re-running the full set every time.

```shell
./scripts/bootstrap                              # install everything
./scripts/bootstrap install core node docker     # install only these categories
./scripts/bootstrap list                         # show available categories
./scripts/bootstrap doctor                       # report missing packages per category
./scripts/bootstrap update                       # explicit: brew update && brew upgrade
```

The first run will also (when missing) prompt for **Xcode Command Line Tools** and install **Homebrew**.

### Categories

| Category | What it installs |
|---|---|
| `core` | ffmpeg, git, httpie, imagemagick, mas, rename, tree, webkit2png, btop, fresh-editor |
| `node` | fnm, then `fnm install --lts && fnm default lts-latest` |
| `cloud` | awscli, kubernetes-cli, kind, eksctl (Weaveworks tap) |
| `docker` | docker cask, docker-compose, and CLI plugin symlink under `~/.docker/cli-plugins/` |
| `terminal` | iTerm2, cmux, Hack Nerd Font, Meslo LG Nerd Font |
| `apps-daily` | Raycast, Rectangle, Chrome, Firefox, Slack, Notion, Spotify, GitHub |
| `apps-dev` | VS Code, Postman, ngrok, Robo 3T, Altair GraphQL Client, Figma, Nucleo, ImageOptim, Transmit, Tor Browser |
| `mas` | Mac App Store: Xcode (497799835), Line (539883307), Amphetamine (937984704) — requires a signed-in App Store |

To add or remove a package, edit the relevant `scripts/brewfiles/Brewfile.<category>`. To add a whole new category, drop a new `Brewfile.<name>` in that directory and append the name to `CATEGORIES` in `scripts/bootstrap`.

> **Note on `brew update` / `brew upgrade`** — they're no longer in the default install path (they made every re-run slow). Run `./scripts/bootstrap update` explicitly when you want to refresh and upgrade.

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
6. **Other** — tlrc, thefuck, fnm, go.
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
