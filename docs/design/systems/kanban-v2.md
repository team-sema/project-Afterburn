# 백로그 칸반 (v2)

> **운영 보드:** [아이템 칸반](https://app.notion.com/p/102c71bf78394bcaa9ff627548faf7f9?v=3c9b8c11155f8111bfeb000c00cae3b8) (`team-sema` · 주간 회의록과 형제)  
> **규칙:** `.cursor/rules/kanban-tickets.mdc`  
> **Pages 스냅샷:** [`docs/board/`](../../board/)

티켓 열 이동은 Notion `상태`가 정본이다. `/feature`·`/push`는 `docs/board/cards.json`의 `column`을 고치지 않는다.

## 열

아이디어 / 백로그 → 스펙 작성 중 → 구현 대기 → 구현 중 → 검증 대기 → 수정 필요 → 완료

- `/push` 기본 도착: **검증 대기**
- **완료**: 사람이 플레이/검증 확인 후에만 (에이전트 `/push`만으로 금지)

## 카드 = feature slug

`feature/player-augment-behaviors` → Notion `카드 ID` `player-augment-behaviors`

## 팀 반영 경로

| 경로 | 언제 |
|------|------|
| 에이전트가 Notion `상태` 수정 | `/feature`, `/push`, 칸반만 편집, 검증 피드백 |
| 사람이 Notion에서 드래그 | 회의·검증 후 직접 옮겨도 됨 |
| Pages 보드 → 프롬프트 복사 → Cursor | 붙여넣으면 **Notion**에만 반영 (git `cards.json` 아님) |

보드의 JSON 복사·다운로드는 쓰지 않는다.

## Pages

Settings → Pages → branch `main` / folder `/docs`  
칸반 URL: `/board/` · 스펙: `/spec/` · 홈: `/`  
Pages 보드는 스냅샷이며 에이전트 열 이동 대상이 아니다.

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-28 | `/feature`·`/push` 열 이동을 Notion 아이템 칸반으로 이전 |
| 2026-07-28 | 보드→에이전트 프롬프트 복사 반영 경로로 갱신 (JSON 다운로드 폐기) |
| 2026-07-22 | Afterburn용 칸반 v2 문서 추가 (cat_dice 패턴 이식) |
