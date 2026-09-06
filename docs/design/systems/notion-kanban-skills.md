# Feature: Notion 칸반 스킬 연동

## 목적

`/feature`·`/push`·검증 피드백이 git `docs/board` column이 아니라 Notion 아이템 칸반 `상태`를 옮긴다.

## 동작 조건

- slug = Notion `카드 ID`
- 없으면 아이템 칸반에 페이지 생성
- `/push` 기본 도착: `검증`
- `/push`만으로 `완료` 금지

## Acceptance Criteria

- [x] `kanban-tickets` 룰이 Notion DB·열 매핑·MCP 절차를 명시한다.
- [x] start-feature / push / merge / Cursor feature·push 스킬이 Notion 열 이동을 가리킨다.
- [x] `/push` 커밋에 `docs/board/` 티켓 파일을 넣지 않는다고 명시한다.
- [x] kanban-v2·board README가 운영 보드를 Notion으로 적는다.

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-29 | Pages `/board/` 제거; 에이전트는 제목·본문만 추천 |
| 2026-08-28 | 초안 |
