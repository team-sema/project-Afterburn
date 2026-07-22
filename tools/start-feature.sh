#!/usr/bin/env bash
# main 최신 기준으로 feature/* 브랜치 생성
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: not a git repository"
  exit 1
}
cd "$ROOT"

if [[ $# -lt 1 ]]; then
  echo "Usage: tools/start-feature.sh <short-name>"
  echo "  example: tools/start-feature.sh dice-roll  →  feature/dice-roll"
  exit 1
fi

SLUG="$1"
BRANCH="feature/${SLUG}"
REMOTE="origin"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: uncommitted changes. commit or stash first."
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "error: branch $BRANCH already exists"
  exit 1
fi

if git remote get-url "$REMOTE" >/dev/null 2>&1; then
  git fetch "$REMOTE"
  git checkout main
  git pull "$REMOTE" main
else
  git checkout main
fi

git checkout -b "$BRANCH"
echo "==> on $BRANCH (from main)"
echo "    work → commit → tools/merge-feature.sh"
