# Feature: Notion 칸반 스킬 연동

> 과거 기능 작업의 설계·결정 이력입니다. 아래 수치·상태·문서 운영 지침은 당시 기록이며 현재 구현 기준이 아닙니다. 현재 기준은 [통합 기획서](../README.md)를 따릅니다. 미구현 제안은 별도 확정 없이 구현하지 않습니다.

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
