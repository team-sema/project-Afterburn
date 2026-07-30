# 적 편대·자폭 이동

## 목표

- Drone: 5마리 고정 편대 + 얕은 대각 하강(측면 ping-pong)
- Striker: 직하강 → 중앙 정지 → 좌우 패트롤
- Awl 자폭: 하강 → 조준 → 락온 돌진 (투사체 없음)

## 구현

- `FormationDiagonalMoveComponent`, `StrikerDivePatrolComponent`, `KamikazeAimChargeComponent`
- `enemy_awl.svg`, `kamikaze_enemy.tscn`
- 2026-07-31 `feature/striker-zigzag-formation` → main (검증 대기)
