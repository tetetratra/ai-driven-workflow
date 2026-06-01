#!/usr/bin/env bash
set -euo pipefail

# ai-driven-workflow を導入先リポジトリへセットアップするスクリプト。
# 導入先の .github/workflows/ に薄いトリガ workflow を設置する。
#
# 使い方:
#   # ツールリポジトリを clone した状態で:
#   bash bin/install.sh [--repo <owner/repo>] [--ref <ref>] [--target <dir>]
#
#   # curl 経由で:
#   curl -fsSL https://raw.githubusercontent.com/tetetratra/ai-driven-workflow/main/bin/install.sh \
#     | bash -s -- --repo tetetratra/ai-driven-workflow --ref main

AIDW_REPO="tetetratra/ai-driven-workflow"
AIDW_REF="main"
TARGET_DIR="."

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --repo <owner/repo>  参照するツールリポジトリ (default: tetetratra/ai-driven-workflow)
  --ref  <ref>         参照する ref。ブランチ(main)で常に最新追従 / タグ / SHA (default: main)
  --target <dir>       導入先リポジトリのルート (default: 現在のディレクトリ)
  -h, --help           このヘルプを表示
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) AIDW_REPO="$2"; shift 2 ;;
    --ref) AIDW_REF="$2"; shift 2 ;;
    --target) TARGET_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

workflows="ai-pr-issue-bootstrap.yml ai-pr-comment.yml ai-pr-state-cleanup.yml"

# テンプレートの取得元を決める（ローカル clone があればそれを、なければ raw GitHub から）。
local_templates=""
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  candidate="$script_dir/../templates/workflows"
  if [ -d "$candidate" ]; then
    local_templates="$(cd "$candidate" && pwd)"
  fi
fi

dest_dir="${TARGET_DIR%/}/.github/workflows"
mkdir -p "$dest_dir"

fetch_template() {
  wf="$1"
  if [ -n "$local_templates" ]; then
    cat "$local_templates/$wf"
  else
    curl -fsSL "https://raw.githubusercontent.com/${AIDW_REPO}/${AIDW_REF}/templates/workflows/${wf}"
  fi
}

for wf in $workflows; do
  dest="$dest_dir/$wf"
  fetch_template "$wf" \
    | sed -e "s|__AIDW_REPO__|${AIDW_REPO}|g" -e "s|__AIDW_REF__|${AIDW_REF}|g" \
    > "$dest"
  echo "installed: $dest"
done

cat <<EOF

トリガ workflow を設置しました（参照先: ${AIDW_REPO}@${AIDW_REF}）。
続けて、導入先リポジトリで以下を設定してください。

1) ラベルを作成する（必須: AI主導開発 / 任意: AI CLI 切替ラベル）
   gh label create "AI主導開発" --color BFD4F2 --description "AI 主導で扱う issue/PR ラベル"
   gh label create "AI:codex" --color 0E8A16 --description "AI CLI に Codex を使う"        # 任意
   gh label create "AI:cursor-cli" --color 5319E7 --description "AI CLI に Cursor CLI を使う"  # 任意

2) Secret を設定する（利用する CLI に応じて）
   # Codex を使う場合（trusted machine で codex login 後）
   base64 < "\${CODEX_HOME:-\$HOME/.codex}/auth.json" | tr -d '\n' | gh secret set CODEX_AUTH_JSON_B64
   # Cursor CLI を使う場合
   gh secret set CURSOR_API_KEY --body "<your-cursor-api-key>"
   # 状態の暗号化（推奨）
   gh secret set STATE_ENCRYPTION_PASSPHRASE --body "<任意の強固なパスフレーズ>"

3) 既定 CLI を切り替える場合（任意。ラベル未指定時のデフォルト。既定は codex）
   gh variable set AI_CLI_TOOL --body "cursor-cli"

4) 設置した workflow を commit & push する
   git add .github/workflows && git commit -m "chore: AI主導開発ワークフローを導入" && git push

使い方: issue に「AI主導開発」ラベルを付けて起票すると PR が自動作成され、
その PR へのコメントで AI が起動します。
EOF
