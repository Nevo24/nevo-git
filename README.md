# nevo-git

Git aliases, branch helpers, and worktree management for zsh.

## Install

```bash
brew tap Nevo24/nevo
brew install nevo-git
```

Add to your `~/.zshrc`:

```bash
source "$(brew --prefix)/share/nevo-git/nevo-git.zsh"
```

Then restart your shell or run `source ~/.zshrc`.

## Update

```bash
brew update && brew upgrade nevo-git
```

## What you get

- Purple git branch in your prompt (auto-configured)
- Short aliases for everyday git commands
- Smart branch operations that auto-detect `main`/`master`
- Worktree management with a simple `wt` command
- `gmr` / `gpr` to open GitLab MRs and GitHub PRs in your browser

Type `nevo-git` in your terminal to see all commands.

## Commands

### Aliases

| Command | What it does |
|---------|-------------|
| `gits` | `git status` |
| `glog` | `git log --name-only` |
| `gco` | `git checkout` |
| `gpull` | `git pull --rebase origin main` |
| `gpush` | `git push` |
| `gpushl` | `git push --force-with-lease` |
| `gbranch` | `git branch` |
| `gdiff` | difftool against a branch/commit |
| `gdm` | difftool against origin's main branch |
| `gec` | empty commit (trigger deploy) |
| `ga` | stage all + amend last commit |
| `grc` | `git rebase --continue` |
| `gsu` | `git submodule update --init --recursive` |
| `conflicts` | `git mergetool -y` |
| `reflog` | `git reflog --date=unix` |
| `guntrack <file>` | remove file from tracking + add to `.gitignore` |

### Branch Operations

| Command | What it does |
|---------|-------------|
| `gcom` | checkout the main branch (auto-detected) |
| `greset [branch]` | hard reset to origin/branch (confirms first) |
| `gresetc` | `greset` on the current branch |
| `grebase [branch]` | `pull --rebase` from origin/branch |
| `grebasec` | `grebase` on the current branch |
| `grebasemy [branch]` | rebase keeping your changes on conflicts (`-X ours`) |
| `grename <new>` | rename current branch (or `grename <old> <new>`) |
| `gdelete <branch>` | delete branch locally and on remote (confirms first) |
| `gnewcommit "msg"` | amend last commit with a new message |
| `gmr` | open the GitLab MR for the current branch in browser |
| `gpr` | open the GitHub PR for the current branch in browser |

### Utilities

| Command | What it does |
|---------|-------------|
| `find_main_branch` | detect the repo's default branch (main/master/etc) |
| `git_url` | print the HTTPS URL of origin |

### Worktree Management

| Command | What it does |
|---------|-------------|
| `wt <branch>` | create/enter a worktree in a sibling `-worktrees` dir |
| `wtm` | jump back to the main repo from a worktree |
| `wtrm <branch>` | remove a worktree (confirms first) |

## Requirements

- zsh
- `jq` and `curl` (for `gmr`/`gpr`)
- `$GITLAB_TOKEN` env var (for `gmr`)
- `$GITHUB_TOKEN` env var (for `gpr`)

---

## For Maintainers

### Releasing a new version

After editing `nevo-git.zsh`, run:

```bash
./release.sh "description of changes"
```

This will:
1. Commit and push your changes
2. Auto-bump the patch version and create a git tag
3. Update the Homebrew formula with the new SHA
4. Push the formula to `homebrew-nevo`

If you've already committed, you can run it without changes — it will just tag and release:

```bash
./release.sh
```

### Repo structure

| File | Purpose |
|------|---------|
| `nevo-git.zsh` | The plugin (all commands + help) |
| `release.sh` | Automated release script |
| [`homebrew-nevo`](https://github.com/Nevo24/homebrew-nevo) | The Homebrew tap (separate repo) |

## License

MIT
