#!/usr/bin/env bash
# Bootstrap this checkout for Codex: install dependencies, refresh the
# repository skill snapshot, and configure the Gemini API key environment.
set -u

main() {
    local script_dir errors=0
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 not found on PATH." >&2
        return 1
    fi

    echo "--- Installing Python dependencies ---"
    python3 -m pip install -q -r "$script_dir/requirements.txt" || errors=$((errors + 1))

    echo
    echo "--- Refreshing the Codex skill snapshot ---"
    python3 "$script_dir/refresh_skill.py" || errors=$((errors + 1))

    echo
    echo "--- Setting up the Gemini API key ---"
    local previous_dir="$PWD"
    cd "$script_dir" || return 1
    . ./set_env.sh || errors=$((errors + 1))
    cd "$previous_dir" || return 1

    echo
    if [ "$errors" -eq 0 ]; then
        echo "--- Setup complete ---"
        echo "Start Codex from $script_dir. The repository skill is under"
        echo ".agents/skills and the MCP server is configured in .codex/config.toml."
        echo "Use /mcp in Codex to confirm that 'nb2lite-agent' is active."
    else
        echo "Setup finished with $errors error(s); see warnings above." >&2
        return 1
    fi
}

main "$@"
