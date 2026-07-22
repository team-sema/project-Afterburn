# 백로그 칸반 (v2)

> **보드 UI:** [`docs/board/`](../../board/)  
> **규칙:** `.cursor/rules/kanban-tickets.mdc`  
> **참고 패턴:** [cat_dice_game 보드](https://team-sema.github.io/cat_dice_game/board/)

Issues/Projects 없이 `cards.json` + `cards/<id>.md`로 티켓을 관리한다.

## 열

아이디어 → 스펙 작성 중 → 구현 대기 → 구현 중 → 검증 대기 → 수정 필요 → 완료

- `/push` 기본 도착: **`review`**
- **`done`**: 사람이 플레이/검증 확인 후에만 (에이전트 자동 금지)

## 카드 = feature slug

`feature/player-augment-behaviors` → 카드 id `player-augment-behaviors`

## Pages

Settings → Pages → branch `main` / folder `/docs`  
칸반 URL: `/board/` · 스펙: `/spec/` · 홈: `/`

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-22 | Afterburn용 칸반 v2 문서 추가 (cat_dice 패턴 이식) |
