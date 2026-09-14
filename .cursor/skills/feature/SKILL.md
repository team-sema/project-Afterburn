---
name: feature
description: >-
  End-to-end feature workflow for Project Afterburn: document first, task breakdown,
  implementation, self-audit, summary. Use for /feature or when the user requests
  a new game feature. Read and update the relevant design document before implementation.
disable-model-invocation: true
---

# Feature

## 순서

브랜치 → 주제별 기획서 갱신 → Task → 구현 → 자체 검증 → 결과 요약.

1. 요청에서 짧은 영문 slug와 수정 경로를 정한다. `feature/<slug>`에서만 편집한다. 일반 시작은 `tools/start-feature.sh`를 사용한다. 사용자가 병렬 작업을 위해 별도 worktree를 요청하면 커밋된 기준 브랜치에서 만들고 원본 작업을 보존한다.
2. `docs/design/README.md`에서 관련 기획서를 찾고 먼저 갱신한다. 의도·동작·수치·예외·화면·완료 조건을 같은 문서에 둔다. 새 독립 주제만 `docs/design/<topic>.md`로 추가하고 README·design.js에 등록한다.
3. `docs/design/tasks/<slug>-tasks.md`에 기획서 링크·작업 순서·수정 예상/금지 경로·검증 방법을 적는다. 기능 규칙을 Task에 복제하지 않는다.
4. 확정된 기획만 구현한다. 필요한 판단이 미결정이면 질문 또는 TODO로 남긴다. 관련 없는 게임 규칙·API·리팩터링을 추가하지 않는다.
5. 구현 후 기획서의 이번 변경을 확정 규칙으로 반영하고 구현 상태·검증 결과를 갱신한다.
6. 결과에 기획서 경로, 변경 내용, 검증 결과, 미구현·확인 필요 항목을 보고한다. 커밋·push는 사용자 요청 시에만 한다.

## 문서 기준

- 구현 기준은 주제별 기획서 한 곳이다. 별도 시스템 설계서·구현 스펙은 만들지 않는다.
- `docs/design/history/`는 과거 기록이며 현재 동작보다 우선하지 않는다. 기능마다 이력 설계서를 새로 만들지 않는다.
- 같은 대화의 피드백에도 기획서 → Task → 코드 → 검증을 적용한다.
- 순수 오타·리네이밍처럼 규칙 영향이 없으면 기획 변경을 생략하고 이유를 보고한다.
- 양식: `docs/design/template.md`; 운영: `docs/design/feature-workflow.md`.
- 수정한 기획서의 변경 이력을 갱신한다.

## 자체 검증

기획의 완료 조건과 실제 동작을 비교한다. 요청 밖 변경·수정 금지 경로·관련 문서 모순·테스트 결과를 확인하고 남은 항목을 명시한다. Godot 실행은 `tools/run-godot.cmd`를 사용한다.

## 칸반

`.cursor/rules/kanban-tickets.mdc`를 따른다. Notion 카드 제목·본문 초안만 추천하며 사용자 명시 요청 없이 생성·이동하지 않는다.
