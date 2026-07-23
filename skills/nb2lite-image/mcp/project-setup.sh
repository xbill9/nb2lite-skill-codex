#!/usr/bin/env bash
# Install the nb2lite-image skill and register its MCP server for Codex.
set -euo pipefail

SKILL_NAME="nb2lite-image"
SERVER_NAME="nb2lite-agent"
MODEL_NAME="gemini-3.1-flash-lite-image"
OUTPUT_DIR=""
SKIP_DEPS=0
GLOBAL=0
TARGET=""

usage() {
    cat <<'EOF'
Usage:
  mcp/project-setup.sh /path/to/project [options]
  mcp/project-setup.sh --global [options]

Options:
  --model <name>        Gemini model name
  --output-dir <dir>    Directory for saved images
  --server-name <name>  MCP server name (default: nb2lite-agent)
  --skip-deps           Skip the Python dependency check
  -h, --help            Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --global) GLOBAL=1 ;;
        --model) MODEL_NAME="$2"; shift ;;
        --output-dir) OUTPUT_DIR="$2"; shift ;;
        --server-name) SERVER_NAME="$2"; shift ;;
        --skip-deps) SKIP_DEPS=1 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        *) [ -z "$TARGET" ] || { echo "Only one target directory may be given." >&2; exit 1; }; TARGET="$1" ;;
    esac
    shift
done

if [ "$GLOBAL" -eq 0 ] && [ -z "$TARGET" ]; then usage; exit 1; fi
if [ "$GLOBAL" -eq 1 ] && [ -n "$TARGET" ]; then
    echo "--global and a target directory are mutually exclusive." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "$GLOBAL" -eq 1 ]; then
    DEST="$HOME/.agents/skills/$SKILL_NAME"
else
    TARGET="$(cd "$TARGET" && pwd)"
    DEST="$TARGET/.agents/skills/$SKILL_NAME"
fi

mkdir -p "$DEST/mcp" "$DEST/references" "$DEST/agents"
cp "$SKILL_SRC/SKILL.md" "$DEST/SKILL.md"
cp "$SKILL_SRC/agents/openai.yaml" "$DEST/agents/openai.yaml"
cp "$SKILL_SRC/mcp/server.py" "$DEST/mcp/server.py"
cp "$SKILL_SRC/mcp/requirements.txt" "$DEST/mcp/requirements.txt"
cp "$SKILL_SRC/mcp/project-setup.sh" "$DEST/mcp/project-setup.sh"
chmod +x "$DEST/mcp/project-setup.sh" 2>/dev/null || true
cp "$SKILL_SRC"/references/*.md "$DEST/references/"
echo "Installed skill to $DEST"

if [ "$SKIP_DEPS" -eq 0 ] && ! python3 -c "import google.genai, mcp" >/dev/null 2>&1; then
    echo "Missing Python dependencies. Install with:"
    echo "  pip install -r $DEST/mcp/requirements.txt"
fi

if [ "$GLOBAL" -eq 1 ]; then
    if ! command -v codex >/dev/null 2>&1; then
        echo "Codex CLI not found. Register the server after installing Codex:"
        echo "  codex mcp add $SERVER_NAME --env GEMINI_MODEL_NAME=$MODEL_NAME -- python3 $DEST/mcp/server.py"
        exit 0
    fi
    codex mcp remove "$SERVER_NAME" >/dev/null 2>&1 || true
    args=(codex mcp add "$SERVER_NAME" --env "GEMINI_MODEL_NAME=$MODEL_NAME")
    [ -n "$OUTPUT_DIR" ] && args+=(--env "IMAGE_OUTPUT_DIR=$OUTPUT_DIR")
    args+=(-- python3 "$DEST/mcp/server.py")
    "${args[@]}"
    echo "Registered '$SERVER_NAME' in the user Codex configuration."
else
    CONFIG_FILE="$TARGET/.codex/config.toml"
    mkdir -p "$TARGET/.codex"
    CONFIG_FILE="$CONFIG_FILE" DEST="$DEST" SERVER_NAME="$SERVER_NAME" \
    MODEL_NAME="$MODEL_NAME" OUTPUT_DIR="$OUTPUT_DIR" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["CONFIG_FILE"])
name = os.environ["SERVER_NAME"]
start = f"# BEGIN nb2lite installer: {name}"
end = f"# END nb2lite installer: {name}"
output = os.environ["OUTPUT_DIR"]
lines = [
    start,
    f'[mcp_servers."{name}"]',
    'command = "python3"',
    f'args = ["{os.environ["DEST"]}/mcp/server.py"]',
    'env_vars = ["GEMINI_API_KEY", "GOOGLE_API_KEY"]',
    "",
    f'[mcp_servers."{name}".env]',
    f'GEMINI_MODEL_NAME = "{os.environ["MODEL_NAME"]}"',
]
if output:
    lines.append(f'IMAGE_OUTPUT_DIR = "{output}"')
lines.extend([end, ""])
block = "\n".join(lines)
text = path.read_text() if path.exists() else ""
if start in text and end in text:
    before, rest = text.split(start, 1)
    _, after = rest.split(end, 1)
    text = before.rstrip() + "\n\n" + block + after.lstrip("\n")
else:
    text = text.rstrip() + ("\n\n" if text.strip() else "") + block
path.write_text(text)
PY
    echo "Registered '$SERVER_NAME' in $CONFIG_FILE"
fi

echo "Export GEMINI_API_KEY before launching Codex, then use /mcp to verify the server."
