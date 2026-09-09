#!/usr/bin/env bash
set -euo pipefail

if [ -z "${AI_CLI_TOOL:-}" ]; then
  echo "AI_CLI_TOOL is required" >&2
  exit 1
fi

if [ -z "${ISSUE_TITLE_FILE:-}" ]; then
  echo "ISSUE_TITLE_FILE is required" >&2
  exit 1
fi

if [ -z "${OUTPUT_FILE:-}" ]; then
  echo "OUTPUT_FILE is required" >&2
  exit 1
fi

issue_title="$(cat "$ISSUE_TITLE_FILE")"
work_dir="$(mktemp -d)"
prompt_file="${work_dir}/prompt.txt"
result_file="${work_dir}/result.txt"

cat > "$prompt_file" <<EOF
GitHub issue タイトルを、簡潔な英語の kebab-case な branch slug に変換してください。

制約:
- 接頭辞は含めない
- 英小文字・数字・ハイフンだけを使う
- 48文字以内
- 回答は slug 文字列だけにする
- コードブロックや説明文は出力しない

Issue タイトル:
${issue_title}
EOF

case "$AI_CLI_TOOL" in
  codex)
    codex exec \
      --model "${CODEX_MODEL:-gpt-5.5}" \
      --dangerously-bypass-approvals-and-sandbox \
      --ignore-user-config \
      --color never \
      --output-last-message "$result_file" \
      -C "$work_dir" \
      - < "$prompt_file" >/dev/null
    ;;
  cursor-cli)
    if [ -z "${CURSOR_API_KEY:-}" ]; then
      echo "CURSOR_API_KEY is required" >&2
      exit 1
    fi
    export PATH="$HOME/.local/bin:/root/.local/bin:/home/node/.local/bin:$PATH"
    agent -p \
      --force \
      --model "composer-2.5" \
      --output-format text \
      --workspace "$work_dir" \
      "$(cat "$prompt_file")" > "$result_file"
    ;;
  *)
    echo "unsupported AI_CLI_TOOL: $AI_CLI_TOOL" >&2
    exit 1
    ;;
esac

slug="$(sed -n '1p' "$result_file" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"
slug="${slug:0:48}"

printf '%s\n' "$slug" > "$OUTPUT_FILE"
