# 汎用 AI runner イメージ。
# プロジェクト固有のビルド/テスト依存は含めない。必要な場合は導入先で
#   - ai-pr-common.yml の `runner_dockerfile` 入力で独自 Dockerfile を指定する、または
#   - `setup_script` 入力で AI 実行前に依存をインストールする
# のいずれかで拡張する。
FROM node:20-bookworm-slim

ARG GH_VERSION=2.74.2

RUN apt-get update && apt-get install -y --no-install-recommends \
  bash \
  ca-certificates \
  curl \
  git \
  jq \
  openssh-client \
  ripgrep \
  tar \
  unzip \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) gh_arch="amd64" ;; \
    arm64) gh_arch="arm64" ;; \
    *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${gh_arch}.tar.gz" -o /tmp/gh.tgz; \
  tar -xzf /tmp/gh.tgz -C /tmp; \
  install "/tmp/gh_${GH_VERSION}_linux_${gh_arch}/bin/gh" /usr/local/bin/gh; \
  rm -rf /tmp/gh.tgz "/tmp/gh_${GH_VERSION}_linux_${gh_arch}"

RUN npm install -g @openai/codex

RUN curl https://cursor.com/install -fsS | bash

ENV PATH="/root/.local/bin:/home/node/.local/bin:/root/.cursor/bin:${PATH}"

WORKDIR /workspace
