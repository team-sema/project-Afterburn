# Feature: 칸반 카드 수동 관리

> 과거 기능 작업의 설계·결정 이력입니다. 아래 수치·상태·문서 운영 지침은 당시 기록이며 현재 구현 기준이 아닙니다. 현재 기준은 [통합 기획서](../README.md)를 따릅니다. 미구현 제안은 별도 확정 없이 구현하지 않습니다.

## 목적

`/push`·`/merge-feature`에서 Notion 카드를 자동 생성·열 이동·태그 설정하지 않고, **제목·본문 초안만 추천**한다. 카드·열·태그는 사람이 Notion에서 관리한다.

## 동작 조건

- `/push` 응답에 `### 칸반 (수동)` 블록 필수 (추천 제목·추천 본문)
- Notion MCP 없음으로 git push **중단 금지**
- Notion MCP **쓰기**는 사용자 명시 요청 시만
- git `docs/board/`·Pages 칸ban **사용 안 함** (2026-08-29 제거)

## Acceptance Criteria

- [x] `kanban-tickets` 룰이 자동 생성·열 이동 금지·제목·본문 추천을 명시한다.
- [x] push / merge / start-feature / feature 스킬이 동일 정책을 가리킨다.
- [x] kanban-v2·feature-workflow가 Notion 수동 관리를 적는다.

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-29 | Pages `/board/` 제거; 추천 범위를 제목·본문으로 한정 |
| 2026-08-28 | 초안 |
