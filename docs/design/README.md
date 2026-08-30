# 설계 (`docs/design/`)

**기획·기능 설계**가 여기 있다. **지금 코드가 하는 일**은 [`docs/spec/`](../spec/) (구현 스펙 · Pages `/spec/`).

층 구분 정본: [`doc-layers.md`](doc-layers.md)

| 경로 | 역할 | 종류 |
|------|------|------|
| [`doc-layers.md`](doc-layers.md) | 기획 vs 구현 스펙 규칙 | 운영 |
| [`vision.md`](vision.md) | 게임 방향·재미 축 | **기획** |
| [`enemies/`](enemies/) | 적 의도·역할 | **기획** |
| [`systems/`](systems/) | feature별 AC·TBD·이력 | 기능 설계 |
| [`tasks/`](tasks/) | 구현 Task | 기능 설계 |
| [`feature-workflow.md`](feature-workflow.md) | `/feature`·`/push` 요약 | 운영 |
| [`augment-todo.md`](augment-todo.md) | 증강 아이디어 메모 | 기획 메모 |

Notion = [아이템 칸반](https://app.notion.com/p/102c71bf78394bcaa9ff627548faf7f9?v=3c9b8c11155f8111bfeb000c00cae3b8)만 (기획 본문 없음).

## UI 입력 원칙

- 모든 실행 가능한 선택지는 마우스 없이 방향키 또는 동등한 방향 입력과 `ui_accept`만으로 도달하고 결정할 수 있어야 한다.
- 화면을 열거나 하위 모달에서 돌아오면 유효한 선택지에 포커스를 명시적으로 복구한다.
- 비활성·선택 불가능한 항목은 포커스 경로에서 제외한다.
- 방향키 이동은 화면의 공간 배치와 일치하는 명시적 포커스 이웃을 사용한다.
- 마우스 호버와 키보드 포커스는 같은 하이라이트와 미리보기를 제공한다.

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | 기획 vs 구현 스펙 구분 · enemies/ vision 입구 |
