---
name: afterburn-start-feature
description: Use when the user asks /start-feature, start feature, create feature branch, or begin new work in Project Afterburn. Create a feature/* branch from latest main with tools/start-feature.sh and declare the expected path scope before implementation.
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
5. Infer the likely paths (`components/`, `player_ship/`, `enemies/`, `menus/`, `docs/design/...`) this slug should touch. Do not ask the user to write the path list.
6. **Kanban ticket:** Follow `.cursor/rules/kanban-tickets.mdc`. Optionally query Notion for an existing card; if none, **recommend** a card draft (title, description, `카드 ID`, suggested column). Do **not** auto-create or move cards. Do not edit `docs/board/cards.json`.
7. Keep later edits within the inferred feature scope unless the user expands it.

## Never Do

- Do not finish or merge the feature here.
- Do not create or use a `develop` branch.
- Do not change `git config`.
