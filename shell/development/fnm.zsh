###############################################################################
# Setup fnm (fast Node manager)
###############################################################################
# --use-on-cd                    auto-switch on directory change (chpwd hook)
# --version-file-strategy=local  walk up from $PWD; reads .nvmrc and .node-version
#                                (worktree-safe: finds the version file at the
#                                 worktree root, not the main checkout)
# --corepack-enabled             run `corepack enable` after each `fnm install`
#                                so pnpm/yarn shims work without extra steps
eval "$(fnm env --use-on-cd --version-file-strategy=local --corepack-enabled --shell zsh)"
