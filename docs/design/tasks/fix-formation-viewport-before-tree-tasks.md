# Tasks — fix-formation-viewport-before-tree

## Tasks

- [x] `FormationDiagonalMoveComponent` 트리 가드 + deferred apply
- [x] `handle_drone_formation_spawn`에서 `setup_formation`을 `add_child` 이후로 이동
- [x] 현황 스펙 (`components.md`, `enemies.md`) 동기화
- [x] smoke: setup을 add_child 전에 호출하도록 회귀 반영

## AC

- [ ] Drone 편대 스폰 시 `get_viewport_rect` / `!is_inside_tree` 에러 없음
- [ ] `drone_diagonal_formation_smoke_test` PASS

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-07-31 | 초안 |
