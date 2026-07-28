# 백로그 칸반 (v2)

> **보드 UI:** [`docs/board/`](../../board/)  
> **규칙:** `.cursor/rules/kanban-tickets.mdc`

Issues/Projects 없이 `cards.json` + `cards/<id>.md`로 티켓을 관리한다.

## 열

아이디어 → 스펙 작성 중 → 구현 대기 → 구현 중 → 검증 대기 → 수정 필요 → 완료

- `/push` 기본 도착: **`review`**
- **`done`**: 사람이 플레이/검증 확인 후에만 (에이전트 `/push`만으로 금지)

## 카드 = feature slug

`feature/player-augment-behaviors` → 카드 id `player-augment-behaviors`

## 팀 반영 경로

| 경로 | 언제 |
|------|------|
| 에이전트가 `cards.json` 직접 수정 | `/feature`, `/push`, 칸반만 편집 |
| **보드 → 프롬프트 복사 → Cursor** | 사람이 보드에서 드래그한 뒤 (특히 `review`→`done`/`fix`) |

보드의 JSON 복사·다운로드는 쓰지 않는다. 드래그는 localStorage 미리보기이고, **에이전트 프롬프트 복사**로 변경 목록을 Cursor에 붙여 저장소에 반영한다.

## Pages

Settings → Pages → branch `main` / folder `/docs`  
칸반 URL: `/board/` · 스펙: `/spec/` · 홈: `/`

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-28 | 보드→에이전트 프롬프트 복사 반영 경로로 갱신 (JSON 다운로드 폐기) |
| 2026-07-22 | Afterburn용 칸반 v2 문서 추가 (cat_dice 패턴 이식) |
