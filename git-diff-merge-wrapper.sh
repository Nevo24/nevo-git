#!/bin/bash
# nevo-git diff/merge wrapper
# Auto-detects project type and opens the best available diff/merge tool.
# Caches resolved app paths in ~/.cache/nevo-git/ (refreshes daily).

CACHE_DIR="$HOME/.cache/nevo-git"
CACHE_FILE="$CACHE_DIR/app-paths"
CACHE_MAX_AGE=86400  # 1 day in seconds
current_dir=$(pwd)

# ─── App Resolution (cached) ─────────────────────────────────────────────────

__find_app() {
    local name="$1" bundle_id="$2" binary="$3"
    # Check common locations first (fast)
    for base in "/Applications" "$HOME/Applications"; do
        local path="$base/$name.app/Contents/MacOS/$binary"
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    # JetBrains Toolbox location
    local toolbox_app
    toolbox_app=$(find "$HOME/Library/Application Support/JetBrains/Toolbox/apps" -name "$binary" -type f -perm /111 2>/dev/null | head -1)
    if [[ -n "$toolbox_app" ]]; then
        echo "$toolbox_app"
        return 0
    fi
    # Spotlight search (slower, but finds apps anywhere)
    if [[ -n "$bundle_id" ]]; then
        local spotlight_path
        spotlight_path=$(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null | head -1)
        if [[ -n "$spotlight_path" && -x "$spotlight_path/Contents/MacOS/$binary" ]]; then
            echo "$spotlight_path/Contents/MacOS/$binary"
            return 0
        fi
    fi
    return 1
}

__find_app_multi() {
    # Try multiple app names in order, return the first found
    local result
    while [[ $# -ge 3 ]]; do
        result=$(__find_app "$1" "$2" "$3")
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
        shift 3
    done
    return 1
}

__load_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        local age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
        if (( age < CACHE_MAX_AGE )); then
            source "$CACHE_FILE"
            return 0
        fi
    fi
    return 1
}

__build_cache() {
    mkdir -p "$CACHE_DIR"

    local pycharm goland idea android_studio
    pycharm=$(__find_app_multi \
        "PyCharm" "com.jetbrains.pycharm.professional" "pycharm" \
        "PyCharm CE" "com.jetbrains.pycharm.ce" "pycharm")
    goland=$(__find_app_multi \
        "GoLand" "com.jetbrains.goland" "goland")
    idea=$(__find_app_multi \
        "IntelliJ IDEA CE" "com.jetbrains.intellij.ce" "idea" \
        "IntelliJ IDEA" "com.jetbrains.intellij" "idea")
    android_studio=$(__find_app_multi \
        "Android Studio" "com.google.android.studio" "studio")

    cat > "$CACHE_FILE" <<EOF
PYCHARM_BIN='$pycharm'
GOLAND_BIN='$goland'
IDEA_BIN='$idea'
ANDROID_STUDIO_BIN='$android_studio'
EOF
    source "$CACHE_FILE"
}

__load_cache || __build_cache

# ─── Fallback Message ────────────────────────────────────────────────────────

__nevo_git_fallback_message() {
    echo ""
    echo "=================================================="
    echo "  nevo-git: Using basic fallback diff/merge tool."
    echo ""
    echo "  For a much better experience, install one of:"
    echo "    - PyCharm (recommended) — brew install --cask pycharm-ce"
    echo "      (Community Edition is free and works great)"
    echo "    - GoLand                — brew install --cask goland"
    echo "    - IntelliJ IDEA CE      — brew install --cask intellij-idea-ce"
    echo "    - VS Code               — brew install --cask visual-studio-code"
    echo "=================================================="
    echo ""
}

# ─── Run Tool ────────────────────────────────────────────────────────────────

__run_tool() {
    local bin="$1"
    shift
    if [[ -n "$bin" && -x "$bin" ]]; then
        "$bin" "$@"
        return 0
    fi
    return 1
}

__run_fallback() {
    local mode="$1"
    shift
    __nevo_git_fallback_message
    if command -v opendiff &>/dev/null; then
        if [[ "$mode" = "merge" ]]; then
            # $1=LOCAL $2=BASE $3=REMOTE $4=MERGED
            opendiff "$1" "$3" -ancestor "$2" -merge "$4"
        else
            opendiff "$@"
        fi
    else
        if [[ "$mode" = "merge" ]]; then
            # $1=LOCAL $2=BASE $3=REMOTE $4=MERGED
            diff3 -m "$1" "$2" "$3" > "$4" 2>/dev/null || diff "$1" "$3"
        else
            diff "$@"
        fi
    fi
}

# ─── Project Detection ───────────────────────────────────────────────────────

# 1. PyCharm — Python projects
if ls "$current_dir"/*.py &>/dev/null || [ -f "$current_dir/requirements.txt" ] || [ -d "$current_dir/venv" ] || [ -f "$current_dir/pyproject.toml" ]; then
    __run_tool "$PYCHARM_BIN" "$@" || __run_fallback "$@"

# 2. GoLand — Go projects
elif ls "$current_dir"/*.go &>/dev/null || [ -f "$current_dir/go.mod" ]; then
    __run_tool "$GOLAND_BIN" "$@" || __run_fallback "$@"

# 3. IntelliJ IDEA — Java projects
elif ls "$current_dir"/*.java &>/dev/null || [ -f "$current_dir/pom.xml" ] || [ -f "$current_dir/build.gradle" ]; then
    __run_tool "$IDEA_BIN" "$@" || __run_fallback "$@"

# 4. Android Studio — Android projects
elif [ -f "$current_dir/local.properties" ] || [ -d "$current_dir/app" ]; then
    __run_tool "$ANDROID_STUDIO_BIN" "$@" || __run_fallback "$@"

# 5. Fallback
else
    __run_fallback "$@"
fi
