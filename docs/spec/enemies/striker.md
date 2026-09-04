# Striker (Yellow)

| 항목 | 값 |
|------|-----|
| 씬 | `enemies/moving_enemy.tscn` |
| HP | 60 |
| 점수 | 10 |
| 최소 Threat | 1 |
| 사격 | `EnemyShootComponent` 조준 산탄 |

## Threat 1 사격 (호위 편대)

| `fire_interval` | 볼리 | 발수 | 탄속 | `initial_delay` |
|---|---|---|---|---|
| 4.5 | 2 (`burst_interval` 0.15) | 5 (`spread` 15°) | 80 | 1.5 |

전역 일반 적 사격 안전선을 사용하므로 중심점이 플레이필드 높이의 70% 아래로 내려가면 발사하지 않는다.

## 조합에서 쓰이는 곳

| Encounter | 역할 |
|-----------|------|
| `striker_drone_diamond_5` | Diamond5 최후방(Slot0) · 해제 후 플레이어 돌진 |
| `striker_drone_diamond_13` | Diamond13 꼭짓점 · 동일 산개 규칙 |

레거시 `striker_single`은 풀 미등록.

→ [Encounter 카탈로그](#encounters/catalog) · [Diamond 5](#formations/diamond-5)
