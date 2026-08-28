# Feature: 칸ban 카드 수동 관리

## 목적

`/push`·`/merge-feature`에서 Notion 카드를 자동 생성·열 이동하지 않고, **카드 초안만 추천**한다. 카드는 사람이 Notion에서 관리한다.

## 동작 조건

- `/push` 응답에 `### 칸ban (수동)` 블록 필수
- Notion MCP 없음으로 git push **중단 금지**
- Notion MCP **쓰기**는 사용자 명시 요청 시만

## Acceptance Criteria

- [x] `kanban-tickets` 룰이 자동 생성·열 이동 금지·초안 추천을 명시한다.
- [x] push / merge / start-feature / feature 스킬이 동일 정책을 가리킨다.
- [x] kanban-v2·feature-workflow·board README가 수동 관리를 적는다.

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-28 | 초안 |
