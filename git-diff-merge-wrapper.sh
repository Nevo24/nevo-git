#!/bin/bash
# nevo-git diff/merge wrapper
# Auto-detects project type and opens the best available diff/merge tool.

current_dir=$(pwd)

__nevo_git_fallback_message() {
    echo ""
    echo "=================================================="
    echo "  nevo-git: Using basic fallback diff/merge tool."
    echo ""
    echo "  For a much better experience, install one of:"
    echo "    - PyCharm (recommended) — brew install --cask pycharm-ce"
    echo "      (Community Edition is free and works great)"
    echo "    - IntelliJ IDEA CE      — brew install --cask intellij-idea-ce"
    echo "    - GoLand                — brew install --cask goland"
    echo "    - VS Code               — brew install --cask visual-studio-code"
    echo "=================================================="
    echo ""
}

# 1. Android Studio — Android projects
if [ -f "$current_dir/local.properties" ] || [ -d "$current_dir/app" ]; then
    "/Applications/Android Studio.app/Contents/MacOS/studio" "$@"

# 2. IntelliJ IDEA — Java projects
elif ls "$current_dir"/*.java &>/dev/null || [ -f "$current_dir/pom.xml" ] || [ -f "$current_dir/build.gradle" ]; then
    "/Applications/IntelliJ IDEA CE.app/Contents/MacOS/idea" "$@"

# 3. PyCharm — Python projects
elif ls "$current_dir"/*.py &>/dev/null || [ -f "$current_dir/requirements.txt" ] || [ -d "$current_dir/venv" ] || [ -f "$current_dir/pyproject.toml" ]; then
    "/Applications/PyCharm.app/Contents/MacOS/pycharm" "$@"

# 4. GoLand — Go projects
elif ls "$current_dir"/*.go &>/dev/null || [ -f "$current_dir/go.mod" ]; then
    "/Applications/GoLand.app/Contents/MacOS/goland" "$@"

# 5. Fallback — opendiff (macOS) or plain diff
else
    if command -v opendiff &>/dev/null; then
        __nevo_git_fallback_message
        opendiff "$@"
    else
        __nevo_git_fallback_message
        # Plain diff/merge as last resort
        if [ "$1" = "diff" ]; then
            shift
            diff "$@"
        elif [ "$1" = "merge" ]; then
            shift
            # $1=LOCAL $2=BASE $3=REMOTE $4=MERGED
            diff3 -m "$1" "$2" "$3" > "$4" 2>/dev/null || diff "$1" "$3"
        else
            diff "$@"
        fi
    fi
fi
