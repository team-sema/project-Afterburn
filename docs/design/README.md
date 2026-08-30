# 설계 (`docs/design/`)

Pages: [`/design/`](index.html) · 구현 스펙: [`/spec/`](../spec/)

| 경로 | 내용 |
|------|------|
| [`vision.md`](vision.md) | 방향·플레이 재미 |
| [`enemies/`](enemies/) | 적 의도·역할 |
| [`systems/`](systems/) | feature AC·이력 |
| [`tasks/`](tasks/) | Task |
| [`feature-workflow.md`](feature-workflow.md) | `/feature`·`/push` · 문서 위치 |
| [`augment-todo.md`](augment-todo.md) | 증강 아이디어 메모 |

## UI 입력 원칙

- 실행 가능한 선택지는 방향 입력 + `ui_accept`만으로 도달·결정
- 화면을 열거나 모달에서 돌아오면 유효 항목에 포커스 복구
- 비활성 항목은 포커스 경로에서 제외
- 방향 이동은 화면 배치와 맞는 이웃
- 마우스 호버와 키보드 포커스는 같은 하이라이트·미리보기

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | doc-layers 제거 · 인덱스 단순화 |
| 2026-08-30 | enemies/ vision 입구 |
