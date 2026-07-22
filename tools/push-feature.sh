#!/usr/bin/env bash
# feature/* : 커밋(선택) → origin/main 신규 커밋 있으면 pull 후 중단 → main merge & push
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: not a git repository"
  exit 1
}
cd "$ROOT"

DELETE_BRANCH=0
MSG=""
FEATURE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m)
      MSG="${2:?missing message after -m}"
      shift 2
      ;;
    -y|--yes) DELETE_BRANCH=1; shift ;;
    --no-delete) DELETE_BRANCH=0; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: tools/push-feature.sh -m "feat: message" [options]

  feature/* 브랜치에서: 변경사항 커밋 → main 동기화 검사 → merge & push

Options:
  -m "message"     필수 (미커밋 변경이 있을 때). 이미 깨끗하면 생략 가능
  -y, --yes        머지 후 feature 브랜치 삭제
  -h, --help

Exit codes:
  0  success
  1  error (wrong branch, no -m, commit failed, merge failed)
  2  STOP: origin/main에 새 커밋이 pull 됨 — feature에 main merge 후 재실행
EOF
      exit 0
      ;;
    -*)
      echo "error: unknown option $1"
      exit 1
      ;;
    *)
      FEATURE="$1"
      shift
      ;;
  esac
done

if [[ -z "$FEATURE" ]]; then
  FEATURE="$(git branch --show-current)"
fi

if [[ "$FEATURE" != feature/* ]]; then
  echo "error: must be on feature/* (got: ${FEATURE:-<none>})"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  if [[ -z "$MSG" ]]; then
    echo "error: uncommitted changes. pass -m \"feat: ...\" (Agent: generate message from diff)"
    git status -sb
    exit 1
  fi
  echo "==> commit on $FEATURE"
  git add -A
  git commit -m "$MSG"
fi

MERGE_ARGS=()
[[ "$DELETE_BRANCH" -eq 1 ]] && MERGE_ARGS+=(-y)
MERGE_ARGS+=("$FEATURE")

exec "$(dirname "$0")/merge-feature.sh" "${MERGE_ARGS[@]}"
