#!/bin/bash

# Check if the key file exists
if [ -f "$HOME/gemini.key" ]; then
    GEMINI_API_KEY=$(cat "$HOME/gemini.key")
else
    read -r -p "Enter Gemini KEY: " GEMINI_API_KEY
    echo "$GEMINI_API_KEY" > "$HOME/gemini.key"
fi

# Export GEMINI_API_KEY as primary, and GOOGLE_API_KEY for backward compatibility
export GEMINI_API_KEY
export GOOGLE_API_KEY="$GEMINI_API_KEY"

echo "✅ Environment variables GEMINI_API_KEY and GOOGLE_API_KEY successfully exported."

# Write keys to .env for local shell use. Codex forwards these variables to the
# MCP server through env_vars; credentials are never written to Codex config.
CURRENT_DIR=$(pwd)
ENV_FILE="$CURRENT_DIR/.env"

cat > "$ENV_FILE" <<EOF
GEMINI_API_KEY=$GEMINI_API_KEY
GOOGLE_API_KEY=$GEMINI_API_KEY
EOF

. ./.env

echo "✅ Written API keys to $ENV_FILE"

echo "✅ Launch Codex from this shell so it can forward the exported key."
