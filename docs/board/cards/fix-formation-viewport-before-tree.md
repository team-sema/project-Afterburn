# Drone 편대 viewport 트리 가드

## 목표

- `configure_before_add` / 트리 밖에서 `get_viewport_rect()` 에러 제거
- Drone `setup_formation`은 스폰이 트리에 붙은 뒤에 실행

## AC

- Drone 편대 스폰 시 `!is_inside_tree()` / `get_viewport_rect` 에러 없음
- 대각·ping-pong 이동은 기존과 동일
