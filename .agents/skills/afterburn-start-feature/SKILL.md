---
name: afterburn-start-feature
description: Use when the user asks /start-feature, start feature, create feature branch, or begin new work in Project Afterburn. Create a feature/* branch from latest main, identify the canonical topic design documents, and declare the expected path scope before implementation.
---

# Start Feature Branch

Use this skill only when beginning new work in Project Afterburn. For finishing a feature, use `afterburn-push`.

## Workflow

1. Require a short slug made of lowercase letters, numbers, and hyphens, such as `player-augment-behaviors`.
2. Run from the repo root:

```bash
chmod +x tools/start-feature.sh 2>/dev/null || true
./tools/start-feature.sh <short-name>
```

3. If the working tree is not clean, stop and tell the user to commit or stash first.
4. After the branch is created, report the branch name.
5. Read `docs/design/README.md` and `docs/design/feature-workflow.md`. Identify the smallest existing topic document(s) that own the requested rules; `docs/design/history/` and old Task files are context only.
6. Infer the likely code paths and canonical design documents this slug should touch. Report both after creating the branch; do not ask the user to produce the path list.
7. Plan to update existing prose, tables, numbers, and completion criteria in place. Do not create a separate implementation-spec tree, a per-feature system spec, or a history entry. Create a new topic document only for a genuinely independent, durable subject; then register it in `docs/design/README.md` and `docs/design/design.js`.
8. Create `docs/design/tasks/<slug>-tasks.md` when implementation begins. It links the canonical design documents and records ordered work, scope, and verification without copying gameplay rules or numbers.
9. **Kanban ticket:** Follow `.cursor/rules/kanban-tickets.mdc`. Optionally query Notion for an existing card; if none, **recommend title and body only**. Do **not** auto-create or move cards.
10. Keep later edits within the inferred feature scope unless the user expands it.

## Never Do

- Do not finish or merge the feature here.
- Do not create or use a `develop` branch.
- Do not change `git config`.
