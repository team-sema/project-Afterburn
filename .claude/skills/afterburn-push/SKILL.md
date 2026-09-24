---
name: afterburn-push
description: Use when the user asks /push, push, finish this feature, commit and merge, or complete a feature branch in Project Afterburn. Finish a feature/* branch by inspecting scope, generating a commit message, running tools/push-feature.sh, and stopping safely if origin/main changed.
---

# Push Feature

Use this skill only in Project Afterburn when finishing a feature branch onto main. Prefer this for feature completion. Use `afterburn-start-feature` when beginning. Use `afterburn-merge-feature` only when already committed (merge-only).

## Workflow

1. Inspect branch, status, and scope:

```bash
git branch --show-current
git status
git diff
git diff --staged
git diff --stat
```

2. If not on `feature/*`, stop and guide to `tools/start-feature.sh`.
3. If diff does not match slug/request, warn about scope drift.
4. **Docs·code gate:** Read `docs/design/README.md` and the relevant topic design documents. Compare their rules, numbers, completion criteria, scope, and verification results with the diff. On inconsistency, stop before push.
   - Behavior, numbers, UI, input, spawning, or content changes update the existing canonical topic documents in the same commit.
   - Changes belong in the relevant prose/table/criteria, not only in `이번 변경` or the changelog. Fold completed work into the document's current rules and leave only current status or remaining work in `이번 변경`.
   - Do not require every template heading in an established document. Preserve its useful structure and make the smallest coherent edit.
   - A cross-topic change updates only what each document owns; keep one canonical source for repeated rules or numbers and link from the others.
   - `docs/design/history/` is evidence, not implementation authority. Do not create a per-feature design document, history entry, or `docs/design/tasks/` checklist unless the change establishes a new durable topic document.
   - For changes with no design impact, state the reason instead of making a ceremonial documentation edit.
5. **Kanban (recommend only, before commit):** Follow `kanban-tickets` — output **title and body draft only** (optional slug reference). Do **not** create or move Notion cards. Notion MCP missing must **not** block push.
6. Generate commit message (`feat:` / `fix:` / `docs:` / `godot:`).
7. Run:

```bash
chmod +x tools/push-feature.sh tools/merge-feature.sh 2>/dev/null || true
./tools/push-feature.sh -m "feat: short description"
```

Merges to main and **deletes the feature branch by default**. Pass `--no-delete` only if the branch must be kept.

## Stop Condition (exit 2)

Do not force push. Tell the user to merge main into the feature branch, resolve/verify, then re-run `/push`.

## Godot Check

If scenes/resources/gameplay changed, briefly confirm the flow and check for contradictions with the topic design documents.

## Success

```bash
git checkout main && git pull
```

## Never Do

- `git push --force`, change `git config`, use `develop`, create a PR unless asked.
