# Caster (Pink)

| 항목 | 값 |
|------|-----|
| 씬 | `enemies/shooting_enemy.tscn` |
| HP | 110 |
| 점수 | 25 |
| 최소 Threat | 3 |
| 비주얼 | `enemy_caster.svg` |

## 상단 체공 · 원형 탄막

- `caster_entry_patrol.tres`: `MoveToPositionStep`으로 y=56 진입 후 `HorizontalPatrolMovementStep`
- `RadialBarrageShootComponent`: 주기마다 링 5회 × 20발 (링마다 소각 회전), `base_enemy_projectile`
- 레거시 상태머신 / `EnemyShootComponent`는 `_enter_tree`에서 제거

## 조합

| Encounter | 역할 |
|-----------|------|
| `caster_single` | [Single](#formations/single) 1슬롯 → 즉시 해제 → 개별 패트롤 |
| `x9_caster_drone_orbit` | [X9](#formations/x9) 중심 Caster + Drone 공전 |

→ [Encounter 카탈로그](#encounters/catalog)
