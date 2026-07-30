# 폭탄 근접 자폭

## 목표

- 느리고 체력 많은 폭탄형 적
- 유저 접근 시 ~2초간 빨간색 3회 점멸 후 자폭
- 자폭 범위/연출 = 기존 적 폭발의 1.5배

## 구현

- `enemy_bomb.svg`, `bomb_enemy.tscn`, `BombProximityFuseComponent`
- 2026-07-31 `feature/bomb-proximity-fuse` → main (검증 대기)
