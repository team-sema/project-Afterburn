# Task: bomb-fuse-tree-null

## Canonical docs

- [bomb.md](../enemies/bomb.md)

## Scope

- `components/bomb_proximity_fuse_component.gd`
- `docs/design/enemies/bomb.md`
- `tests/bomb_proximity_fuse_smoke_test.gd`

## Work

1. 점멸 대기 전후에 `is_inside_tree()` / `get_tree()` null을 확인해 트리 이탈 시 신관 코루틴을 중단한다.
2. 점멸 중 `queue_free` 회귀를 smoke에 추가한다.

## Verification

- [x] `.\tools\run-godot.cmd --headless --script res://tests/bomb_proximity_fuse_smoke_test.gd` → PASS
