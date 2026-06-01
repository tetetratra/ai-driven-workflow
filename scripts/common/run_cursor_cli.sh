#!/usr/bin/env bash
set -euo pipefail

# Docker コンテナ内で Cursor CLI を実行する。
# - /workspace: 導入先リポジトリの作業ツリー
# - /aidw: ai-driven-workflow（本ツール）のチェックアウト（scripts / prompts / external/skills）

if [ -z "${STATE_ROOT:-}" ]; then
  echo "STATE_ROOT is required" >&2
  exit 1
fi

if [ -z "${PR_NUMBER:-}" ]; then
  echo "PR_NUMBER is required" >&2
  exit 1
fi

if [ -z "${REPO:-}" ]; then
  echo "REPO is required" >&2
  exit 1
fi

if [ -z "${INSTRUCTION_FILE:-}" ]; then
  echo "INSTRUCTION_FILE is required" >&2
  exit 1
fi

if [ -z "${CURSOR_API_KEY:-}" ]; then
  echo "CURSOR_API_KEY is required" >&2
  exit 1
fi

AIDW_DIR="${AIDW_DIR:-/aidw}"

mkdir -p "$STATE_ROOT/run" "$STATE_ROOT/result"

git config --global --add safe.directory /workspace || true
git config --global --add safe.directory "$AIDW_DIR" || true
export PATH="$HOME/.local/bin:/root/.local/bin:/home/node/.local/bin:$PATH"

run_mode="${RUN_MODE:-normal}"
context_sha="${HEAD_SHA:-$(git -C /workspace rev-parse HEAD)}"
prompt_file="$STATE_ROOT/run/prompt.txt"
events_file="$STATE_ROOT/run/events.txt"
final_file="$STATE_ROOT/result/final.md"
meta_file="$STATE_ROOT/run/meta.json"

cat > "$meta_file" <<EOF
{
  "ai_tool": "cursor-cli",
  "pr_number": "${PR_NUMBER}",
  "pr_url": "${PR_URL:-}",
  "branch_name": "${PR_BRANCH:-}",
  "head_sha": "${context_sha}",
  "run_mode": "${run_mode}",
  "trigger_actor": "${TRIGGER_ACTOR:-}",
  "run_started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

AI_AGENT_NAME="Cursor CLI エージェント" bash "$AIDW_DIR/scripts/common/build_prompt.sh" "$prompt_file"

skills_src="$AIDW_DIR/external/skills/skills"
skills_dest="/workspace/.cursor/skills"
if [ -d "$skills_src" ]; then
  rm -rf "$skills_dest"
  mkdir -p "$skills_dest"

  shopt -s nullglob
  for skill_dir in "$skills_src"/*; do
    [ -d "$skill_dir" ] || continue

    skill_name="$(basename "$skill_dir")"
    if [ "${#skill_name}" -eq 1 ]; then
      continue
    fi

    cp -R "$skill_dir" "$skills_dest/"
  done
fi

# 導入先固有の事前セットアップ（依存インストール等）があれば AI 実行前に走らせる
if [ -n "${SETUP_SCRIPT:-}" ] && [ -f "/workspace/${SETUP_SCRIPT}" ]; then
  echo "Running setup script: ${SETUP_SCRIPT}"
  bash "/workspace/${SETUP_SCRIPT}"
fi

if ! command -v agent >/dev/null 2>&1; then
  echo "agent command not found in PATH" >&2
  exit 1
fi

prompt="$(cat "$prompt_file")"
agent -p --force --model "composer-2.5" --output-format text --workspace /workspace "$prompt" | tee "$events_file"
cp "$events_file" "$final_file"
