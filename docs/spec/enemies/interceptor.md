# Interceptor

| 항목 | 값 |
|------|-----|
| 씬 | `enemies/interceptor_enemy.tscn` (`normal_enemy` 상속) |
| HP | **50** |
| 점수·XP | Drone과 동일 |
| 최소 Threat | 1 (pair) / 3 (trio) |
| 비주얼 | `enemy_interceptor.svg` (기수 +Y) |

## 고속 공격 패스 (유닛·공통)

- `EnemySpawner`가 `ForwardAttackRun`을 좌→우 / 우→좌 랜덤 + dive 각도(약 15~29°)로 배치
- 스폰 Y: VisibleRect 높이의 약 16~38% 상단 밴드
- `start_delay=0.9` 동안 `EntryWarningComponent`가 좌/우 등장 가장자리에 경고 (화살표는 스폰 쪽)
- `ForwardAttackRunMovementStep`: 편대 루트를 진행 방향으로 회전 후 local forward 210px/s. clamp·bounce·재추적 없음
- 화면 진입 후 **0.7초** 사격 창 · **10발 burst 1회만** (`burst_interval` 0.05, `fire_interval` 10으로 재공격 차단)
- 탄: 플레이어 조준 · **300px/s**
- 생존 기체는 DespawnArea 이탈 시 보상 없음 (`no_health` 없음)

## 조합

| Encounter | 진형 |
|-----------|------|
| `interceptor_pair` | [interceptor-pair](#formations/interceptor-pair) (36px 가로 2슬롯) |
| `interceptor_trio` | [V3](#formations/v3) |

단독 Encounter 없음.

→ [Encounter 카탈로그](#encounters/catalog)
