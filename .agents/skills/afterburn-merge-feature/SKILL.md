---
name: afterburn-merge-feature
description: Use when the user asks /merge-feature, merge feature, merge-only, or push an already committed feature branch in Project Afterburn. Merge a clean, already-committed feature/* branch to main with tools/merge-feature.sh and stop safely if origin/main changed.
---

# Merge Feature

Use only for the merge-only workflow when all changes are already committed. For normal completion with uncommitted changes, use `afterburn-push`.

## Workflow

1. Confirm working tree is clean. If not, use `afterburn-push`.
2. Use current `feature/*` unless the user named a branch.
3. Run:

```bash
chmod +x tools/merge-feature.sh 2>/dev/null || true
./tools/merge-feature.sh [options] [feature/branch]
```

Deletes the feature branch after merge by default. Pass `--no-delete` to keep it.

## Stop Condition (exit 2)

Do not force push. Merge main into feature, verify, re-run.

## Never Do

- `git push --force`, change `git config`, use `develop`, create a PR unless asked.
