# docs 스펙·칸반 사이트

> cat_dice_game 보드와 같은 패턴으로 Afterburn 문서 사이트·워크플로를 추가.

## 범위

- `docs/spec/` — 카테고리별 구현 스펙 MD + 브라우저
- `docs/board/` — 7열 칸반 (`cards.json` + `cards/*.md`)
- `docs/design/` — systems/tasks · feature-workflow
- `.cursor/` · `.agents/skills/afterburn-*` · `tools/` — `/feature`·`/push`
- Godot 루트: `mayhem-shmup/` → 리포 루트 승격

## Acceptance

- [x] 스펙을 카테고리별로 열람 가능
- [x] 칸반 드래그 · JSON 복사/저장 · localStorage
- [x] Cursor feature/push 스킬·룰·tools 존재
- [ ] GitHub Pages(`/docs`) Settings에서 활성화 (팀 작업)

## 구현

- 2026-07-22 `feature/docs-site-kanban` → main (검증 대기)
