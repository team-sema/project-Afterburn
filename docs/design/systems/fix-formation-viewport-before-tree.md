# Drone 편대 viewport 트리 가드

## 문제

`SpawnerComponent.spawn`의 `configure_before_add`는 `add_child` **이전**에 실행된다. Drone이 여기서 `setup_formation` → `_apply_position` → `actor.get_viewport_rect()`를 호출하면 `!is_inside_tree()` 에러가 난다.

## 규칙

1. `FormationDiagonalMoveComponent`: actor가 트리에 없으면 `_apply_position`을 deferred하고, `_apply_position`은 `is_inside_tree()`가 아니면 return.
2. `handle_drone_formation_spawn`: 의존성 주입만 `configure_before_add`에서 하고, `setup_formation`은 `spawn` 반환 후(트리 진입 후) 호출.

## AC

- [ ] Drone 편대 스폰 시 viewport 관련 에러 없음
- [ ] 공유 클록 대각·상대 오프셋 유지 (기존 smoke 통과)

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-07-31 | 초안 · 트리 가드 + 스폰 순서 수정 |
