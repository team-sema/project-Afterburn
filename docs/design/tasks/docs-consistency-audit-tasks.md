# docs-consistency-audit Task

스펙: [`docs/design/systems/docs-consistency-audit.md`](../systems/docs-consistency-audit.md)

| # | Task | 파일 | 완료 |
|---|------|------|------|
| 1 | 오그먼트 트리거를 XP·시간 기반으로 정정 · 점수는 표시용임을 명시 | `.cursor/rules/afterburn-project.mdc` | ✅ |
| 2 | 한 줄 소개 정정 + 조작(`C`) 요약 추가 | `README.md` | ✅ |
| 3 | 스펙 트래킹 표 적 풀 3 → 6 | `docs/spec/overview.md` | ✅ |
| 4 | 폴더 맵을 실제 디렉터리·루트 조립 파일로 갱신 | `docs/spec/overview.md` | ✅ |
| 5 | 구조 부채 항목 17~22 추가 · `ResourceStash` 항목 정확화 | `docs/spec/gaps.md` | ✅ |
| 6 | `status-ui-templates` 상태 doing → review | `docs/design/systems/README.md` | ✅ |
| 7 | `fix-formation-viewport-before-tree` 열 doing → review (`bfa5795` main 포함) | `docs/board/cards.json` | ✅ |
| 8 | 풀 수 54/6 정정 · 동력로·실드 재생 절 `done` 처리 · 초안 대비 실제 차이 표 | `docs/design/augment-todo.md` | ✅ |
| 9 | headless 실행을 `tools/run-godot.cmd` 단일 경로로 · 폴더 맵 갱신 | `.cursor/rules/godot-development.mdc` | ✅ |
| 10 | 시스템 스펙·Task·카드 생성 및 인덱스 등록 | `docs/design/`, `docs/board/` | ✅ |

## 검증

- 게임 코드·씬·리소스 변경 0 — `git diff --stat`이 `docs/`·`.cursor/rules/`·`README.md`만 포함해야 한다.
- headless 파스 체크로 리그레션 없음 확인: `.\tools\run-godot.cmd --headless --editor --quit`

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-06 | 초안 · Task 10건 |
