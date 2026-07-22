#!/usr/bin/env bash
# feature/* → main (PR 없이). GitHub branch protection이 PR을 강제하면 이 스크립트도 막힘.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: not a git repository"
  exit 1
}
cd "$ROOT"

DELETE_BRANCH=0
FEATURE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) DELETE_BRANCH=1; shift ;;
    --delete-branch) DELETE_BRANCH=1; shift ;;
    --no-delete) DELETE_BRANCH=0; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: tools/merge-feature.sh [options] [feature/branch-name]

  현재 브랜치가 feature/* 이면 인자 생략 가능.

Options:
  -y, --yes         머지 후 로컬·origin feature 브랜치 삭제 (확인 없음)
  --delete-branch  同上
  --no-delete       브랜치 유지 (기본)
  -h, --help

Flow: fetch → checkout main → pull → merge feature → push main
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
  echo "error: branch must be feature/* (got: ${FEATURE:-<none>})"
  echo "  checkout a feature branch or pass: tools/merge-feature.sh feature/my-work"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: uncommitted changes. commit or stash first."
  git status -sb
  exit 1
fi

if ! git rev-parse --verify "$FEATURE" >/dev/null 2>&1; then
  echo "error: branch '$FEATURE' does not exist locally"
  exit 1
fi

REMOTE="origin"
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "warn: no remote '$REMOTE' — merge locally only"
  REMOTE=""
fi

echo "==> merge $FEATURE → main"
[[ -n "$REMOTE" ]] && git fetch "$REMOTE"

# origin/main에 새 커밋이 있으면 pull 후 중단 (feature에 main 반영은 사람/Agent가 처리)
if [[ -n "$REMOTE" ]] && git rev-parse --verify "$REMOTE/main" >/dev/null 2>&1; then
  if ! git rev-parse --verify main >/dev/null 2>&1; then
    git branch main "$REMOTE/main"
  fi
  behind="$(git rev-list --count main.."$REMOTE/main" 2>/dev/null || echo 0)"
  if [[ "${behind:-0}" -gt 0 ]]; then
    echo "==> $REMOTE/main is ${behind} commit(s) ahead of local main — pulling before merge"
    git checkout main
    before="$(git rev-parse HEAD)"
    git pull "$REMOTE" main
    after="$(git rev-parse HEAD)"
    git checkout "$FEATURE"
    if [[ "$before" != "$after" ]]; then
      echo ""
      echo "STOP: main was updated from $REMOTE (${behind} new commit(s) pulled)."
      echo "  Teammate may have pushed to main. Merge NOT performed."
      echo ""
      echo "  Next:"
      echo "    git merge main          # on $FEATURE (or: git rebase main)"
      echo "    # resolve conflicts, test"
      echo "    /push  or  ./tools/push-feature.sh -m \"...\""
      exit 2
    fi
  fi
fi

git checkout main
if [[ -n "$REMOTE" ]]; then
  git pull "$REMOTE" main
fi

if ! git merge --no-ff "$FEATURE" -m "merge: $FEATURE into main"; then
  echo "error: merge failed. resolve conflicts, then commit and push manually."
  exit 1
fi

if [[ -n "$REMOTE" ]]; then
  git push "$REMOTE" main
  echo "==> pushed main to $REMOTE"
else
  echo "==> merged locally (no remote push)"
fi

if [[ "$DELETE_BRANCH" -eq 1 ]]; then
  git branch -d "$FEATURE" 2>/dev/null || git branch -D "$FEATURE"
  if [[ -n "$REMOTE" ]] && git ls-remote --heads "$REMOTE" "$FEATURE" | grep -q .; then
    git push "$REMOTE" --delete "$FEATURE"
    echo "==> deleted $FEATURE (local + $REMOTE)"
  else
    echo "==> deleted $FEATURE (local)"
  fi
else
  echo "==> kept branch $FEATURE (use -y to delete after merge)"
fi

echo "done. tell teammate: git checkout main && git pull"
