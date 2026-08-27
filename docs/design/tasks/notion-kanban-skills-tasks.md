# Tasks: notion-kanban-skills

## 완료 조건

에이전트 스킬·룰이 칸반 열을 Notion에서만 옮긴다.

## 파일

- `.cursor/rules/kanban-tickets.mdc`
- `.cursor/rules/feature-scope.mdc`, `afterburn-project.mdc`
- `.cursor/skills/feature/SKILL.md`, `.cursor/skills/push/SKILL.md`
- `.agents/skills/afterburn-start-feature/SKILL.md`, `afterburn-push/SKILL.md`, `afterburn-merge-feature/SKILL.md`
- `docs/design/systems/kanban-v2.md`, `docs/board/README.md`

## AC

- [x] `/feature` → Notion `스펙 작성 중` 또는 `구현 중`
- [x] `/push` → Notion `검증 대기`, git `cards.json` 비포함
- [x] 검증 OK → Notion `완료` (에이전트 `/push`만으로 완료 금지 유지)
