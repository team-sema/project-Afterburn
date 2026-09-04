# Drone (Green)

| 항목 | 값 |
|------|-----|
| 씬 | `enemies/normal_enemy.tscn` |
| HP | 28 |
| 점수 | 5 |
| 최소 Threat | 1 |
| 사격 | `EnemyShootComponent` 조준 단발 |

## Threat 1 사격

| `fire_interval` | 볼리 | 발수 | 탄속 | `initial_delay` |
|---|---|---|---|---|
| 4.5 | 1 | 1 | 105 | 1.5 |

이후 난이도는 적 오그먼트 `ACTION_RATE`가 `fire_interval`·`burst_interval`을 나눠 올린다. 탄속에는 배율이 없다.

전역 일반 적 사격 안전선을 사용하므로 중심점이 플레이필드 높이의 60% 아래로 내려가면 발사하지 않는다.

## 조합에서 쓰이는 곳

호위·편대 본체로 가장 많이 쓰인다. 유닛 수치만 여기; 배치·이동은 Encounter.

| Encounter | 역할 |
|-----------|------|
| `drone_formation` | 5기 대각 편대 본체 |
| `drone_zigzag_mirrored` | zigzag 편대 본체 |
| `striker_drone_diamond_5` / `_13` | 호위 |
| `bomb_drone_diamond` | 호위 |
| `v7_drone_down` / `x9_drone_down` | 하강 후 산개 |
| `x9_caster_drone_orbit` | 궤도 호위 |

→ [Encounter 카탈로그](#encounters/catalog) · [진형](#formations)
