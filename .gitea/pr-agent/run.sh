#!/usr/bin/env bash
# Runs one PR-Agent command on a pull request (.gitea/workflows/pr-agent.yml).
#
#   PR_URL=… COMMAND="/ask why a cache?" LLM_KEY=… MODEL=gpt-5.6 GITEA_TOKEN=… run.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Only commands that comment: /describe would rewrite the PR description.
first="${COMMAND%%[[:space:]]*}"
case "$first" in
    /review | /improve | /ask) ;;
    *)
        echo "not a PR-Agent command here: $first"
        exit 0
        ;;
esac
if [[ -z "${LLM_KEY:-}" || -z "${MODEL:-}" ]]; then
    echo "PR_AGENT_LLM_KEY or PR_AGENT_MODEL not set: skipped"
    exit 0
fi

# LiteLLM picks the key by the model's provider.
export CONFIG__MODEL="$MODEL"
export OPENAI__KEY="$LLM_KEY" ANTHROPIC__KEY="$LLM_KEY" GOOGLE_AI_STUDIO__GEMINI_API_KEY="$LLM_KEY"
export OPENROUTER__KEY="$LLM_KEY"

# Context size of a model PR-Agent does not know (most openrouter/… names).
if [[ -n "${MODEL_TOKENS:-}" ]]; then
    export CONFIG__CUSTOM_MODEL_MAX_TOKENS="$MODEL_TOKENS"
fi
export GITEA__URL="$GITEA_URL" GITEA__PERSONAL_ACCESS_TOKEN="$GITEA_TOKEN"

# Settings beyond the defaults: config.toml.
export PR_AGENT_EXTRA_CONFIG_URL="$HERE/config.toml"

# run_command splits the comment like a shell would: /ask "why …?".
exec python -c 'import sys; from pr_agent import cli; cli.run_command(*sys.argv[1:])' "$PR_URL" "$COMMAND"
