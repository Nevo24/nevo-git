#!/usr/bin/env zsh
# nevo-git — Git aliases and functions by Nevo Mashiach
# Source this file in your .zshrc:  source "$(brew --prefix)/share/nevo-git/nevo-git.zsh"

# ─── Aliases ──────────────────────────────────────────────────────────────────

alias gits="git status"
alias gdiff='git add -N . && git difftool -d "${@: -1}" "${@:1:1}"'
alias glog="git log --name-only"
alias gco="git checkout"
alias gpull="git pull --rebase origin main"
alias gpush="git push"
alias gpushl="git push --force-with-lease"
alias gbranch="git branch"
alias gec="git commit --allow-empty -m 'Trigger deploy'"
alias conflicts='git mergetool -y'
alias grc='git rebase --continue'
alias ga='git add --all && git commit --amend'
alias gresetc='greset $(git rev-parse --abbrev-ref HEAD)'
alias grebasec='grebase $(git rev-parse --abbrev-ref HEAD)'
alias guntrack='f() { git rm --cached "$1" && echo "$1" >> .gitignore && git add .gitignore && git commit -m "Remove $1 from version control"; }; f'
alias reflog='git reflog --date=unix'
alias gsu='git submodule update --init --recursive'

# ─── Utility Functions ────────────────────────────────────────────────────────

find_main_branch() {
    local main_branch
    main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    if [ -z "$main_branch" ]; then
        git remote set-head origin --auto &>/dev/null
        main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    fi

    echo "${main_branch:-main}"
}

git_url() {
    git remote get-url origin | sed 's/git@\(.*\):/https:\/\/\1\//'
}

# ─── Branch Operations ───────────────────────────────────────────────────────

gcom() {
    local branch=$(find_main_branch)
    git checkout $branch
}

greset() {
    local branch=${1:-$(find_main_branch)}

    if read -q "choice?Press Y/y to continue with git-full-branch-reset process ($branch): "; then
        echo "\ngit fetch origin"
        git fetch origin
        echo "reset --hard origin/$branch"
        git reset --hard origin/"$branch"
        echo "git clean -f"
        git clean -f
    else
        echo "'$choice' not 'Y' or 'y'. Exiting..."
    fi
}

grebase() {
    local branch=${1:-$(find_main_branch)}
    echo "git pull --rebase origin $branch"
    git pull --rebase origin "$branch"
}

grebasemy() {
    local branch=${1:-$(find_main_branch)}
    git fetch origin "$branch"
    git rebase -X ours "origin/$branch"
}

gdelete() {
    if read -q "choice?Press Y/y to continue with git-branch-deletion (local and remote) process: "; then
        echo "\ngit push origin --delete $1"
        git push origin --delete "$1"
        echo "\ngit branch -D $1"
        git branch -D "$1"
    else
        echo "'$choice' not 'Y' or 'y'. Exiting..."
    fi
}

new_commit() {
    if [ -z "$1" ]; then
        echo "Error: Please provide a new commit message as an argument."
        echo "Usage: new_commit \"Your new commit message here\""
        return 1
    fi
    git commit --allow-empty --amend -m "$1"
}

gdm() {
    local branch=$(find_main_branch)
    gdiff origin/$branch
}

gmr() {
    git rev-parse --is-inside-work-tree &>/dev/null || { echo "No git project"; return 1; }
    local url=$(git_url)
    local branch=$(git branch --show-current)
    local project=$(echo "$url" | sed 's#https://\([^/]*\)/\(.*\)#\1/\2#; s/\.git$//')
    local host=${project%%/*}
    local path=${project#*/}
    local encoded=$(echo "$path" | /usr/bin/jq -Rr @uri)
    local mr_url=$(/usr/bin/curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "https://${host}/api/v4/projects/${encoded}/merge_requests?source_branch=${branch}&state=opened" \
        | /usr/bin/jq -r '.[0].web_url // empty')
    [ -z "$mr_url" ] && { echo "No MR on this branch"; return 1; }
    /usr/bin/open "$mr_url"
}

gpr() {
    git rev-parse --is-inside-work-tree &>/dev/null || { echo "No git project"; return 1; }
    local url=$(git_url)
    local branch=$(git branch --show-current)
    local owner_repo=$(echo "$url" | sed 's#https://github.com/##; s/\.git$//')
    local pr_url=$(/usr/bin/curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/${owner_repo}/pulls?head=$(echo "$owner_repo" | cut -d/ -f1):${branch}&state=open" \
        | /usr/bin/jq -r '.[0].html_url // empty')
    [ -z "$pr_url" ] && { echo "No PR on this branch"; return 1; }
    /usr/bin/open "$pr_url"
}

# ─── Worktree Management ─────────────────────────────────────────────────────

wt() {
    local name="$1"
    local SUFFIX="-worktrees"

    if [[ -z "$name" ]]; then
        echo "usage: wt <branch-name>"
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "wt: not inside a git repository/worktree"
        return 1
    fi

    local common_dir
    common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || { echo "wt: cannot locate git common dir"; return 1; }
    [[ "$common_dir" != /* ]] && common_dir="$(pwd)/$common_dir"

    local main_repo_root
    main_repo_root="$(cd "$common_dir/.." && pwd -P)" || { echo "wt: cannot resolve main repo root"; return 1; }

    local repo_name="${main_repo_root##*/}"
    local parent_dir="${main_repo_root%/*}"
    local base_dir="${parent_dir}/${repo_name}${SUFFIX}"
    local wt_path="${base_dir}/${name}"

    if [[ ! -d "$base_dir" ]]; then
        mkdir -p "$base_dir" || { echo "wt: failed to create $base_dir"; return 1; }
    fi

    if [[ -d "$wt_path" ]]; then
        echo "wt: worktree path already exists -> $wt_path"
        cd "$wt_path" || return 1
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/${name}"; then
        git worktree add "$wt_path" "$name" || { echo "wt: failed to add worktree for existing branch"; return 1; }
    else
        git worktree add -b "$name" "$wt_path" || { echo "wt: failed to create branch/worktree"; return 1; }
    fi

    cd "$wt_path" || return 1
}

wtm() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "wtm: not inside a git repository"
        return 1
    fi

    local wt_root
    wt_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1

    local parent_dir="${wt_root%/*}"
    if [[ "$parent_dir" != *"-worktrees" ]]; then
        echo "wtm: not in a worktree folder (no '-worktrees' in path)"
        return 1
    fi

    local base_dir="${parent_dir%-worktrees}"
    if [[ ! -d "$base_dir" ]]; then
        echo "wtm: original repo folder not found at $base_dir"
        return 1
    fi

    cd "$base_dir" || return 1
    echo "-> moved to main repo: $base_dir"
}

wtrm() {
    local name="$1"
    local SUFFIX="-worktrees"

    if [[ -z "$name" ]]; then
        echo "usage: wtrm <branch-name>"
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "wtrm: not inside a git repository"
        return 1
    fi

    local common_dir
    common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || { echo "wtrm: cannot locate git common dir"; return 1; }
    [[ "$common_dir" != /* ]] && common_dir="$(pwd)/$common_dir"

    local main_repo_root
    main_repo_root="$(cd "$common_dir/.." && pwd -P)" || { echo "wtrm: cannot resolve main repo root"; return 1; }

    local repo_name="${main_repo_root##*/}"
    local parent_dir="${main_repo_root%/*}"
    local base_dir="${parent_dir}/${repo_name}${SUFFIX}"
    local wt_path="${base_dir}/${name}"

    if [[ ! -d "$wt_path" ]]; then
        echo "wtrm: worktree directory does not exist: $wt_path"
        echo "If it exists only in git metadata, run: git worktree prune"
        return 1
    fi

    echo "Removing worktree for branch '$name' at:"
    echo " -> $wt_path"
    read -q "choice?Press Y/y to confirm: "
    echo

    if [[ "$choice" != "Y" && "$choice" != "y" ]]; then
        echo "Aborted."
        return 1
    fi

    git -C "$main_repo_root" worktree remove "$wt_path" -f || {
        echo "git worktree remove failed -- attempting prune"
    }

    rm -rf "$wt_path"
    git -C "$main_repo_root" worktree prune

    echo "Worktree '$name' removed."
}

# ─── Help Command ────────────────────────────────────────────────────────────

nevo-git() {
    cat <<'HELP'
nevo-git — Git shortcuts and worktree management

ALIASES
  gits              git status
  glog              git log --name-only
  gco               git checkout
  gpull             git pull --rebase origin main
  gpush             git push
  gpushl            git push --force-with-lease
  gbranch           git branch
  gdiff             difftool against a branch/commit
  gdm               difftool against origin's main branch
  gec               empty commit (trigger deploy)
  ga                stage all + amend last commit
  grc               git rebase --continue
  gsu               git submodule update --init --recursive
  conflicts         git mergetool -y
  reflog            git reflog --date=unix
  guntrack <f>      remove file from tracking + add to .gitignore

BRANCH OPERATIONS
  gcom              checkout the main branch (auto-detected)
  greset [branch]   hard reset to origin/<branch> (confirms first)
  gresetc           greset on the current branch
  grebase [branch]  pull --rebase from origin/<branch>
  grebasec          grebase on the current branch
  grebasemy [br]    rebase keeping your changes on conflicts (-X ours)
  gdelete <branch>  delete branch locally and on remote (confirms first)
  new_commit "msg"  amend last commit with a new message (allow-empty)
  gmr               open the GitLab MR for the current branch in browser
  gpr               open the GitHub PR for the current branch in browser

UTILITIES
  find_main_branch  detect the repo's default branch (main/master/etc)
  git_url           print the HTTPS URL of origin

WORKTREE MANAGEMENT
  wt <branch>       create/enter a worktree in a sibling -worktrees dir
  wtm               jump back to the main repo from a worktree
  wtrm <branch>     remove a worktree (confirms first)
HELP
}
