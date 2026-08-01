# 설계 (`docs/design/`)

`/feature`로 추가·변경하는 **동작 규칙**의 집약 위치다. 현재 코드 요약은 [`docs/spec/`](../spec/)를 본다.

| 경로 | 역할 |
|------|------|
| [`systems/`](systems/) | 기능별 시스템 스펙 (`<slug>.md`) |
| [`tasks/`](tasks/) | 구현 Task (`<slug>-tasks.md`) |
| [`augment-todo.md`](augment-todo.md) | 증강 아이디어·후보 메모 (미구현) |
| [`feature-workflow.md`](feature-workflow.md) | `/feature`·`/push` 요약 |

워크플로 상세는 `.cursor/skills/feature`, `.cursor/skills/push`, `.cursor/rules/*`.

## UI 입력 원칙

- 모든 실행 가능한 선택지는 마우스 없이 방향키 또는 동등한 방향 입력과 `ui_accept`만으로 도달하고 선택할 수 있어야 한다.
- 화면을 열거나 하위 모달에서 돌아오면 유효한 선택지에 포커스를 명시적으로 복구한다.
- 비활성·선택 불가능한 항목은 포커스 경로에서 제외한다.
- 방향키 이동은 화면의 공간 배치와 일치하는 명시적 포커스 이웃을 사용한다.
- 마우스 호버와 키보드 포커스는 같은 하이라이트와 미리보기를 제공한다.
