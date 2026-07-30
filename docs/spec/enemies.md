# 적

## 타입 (생성기 기준)

| 코드명 | 씬 | HP | 점수 | 특징 |
|--------|-----|-----|------|------|
| Green / Drone | `normal_enemy.tscn` | 20 | 5 | 편대 대각 하강 · 스폰 offset ~5 |
| Yellow / Striker | `moving_enemy.tscn` | 50 | 10 | 직하강 → 중앙 정지 → 좌우 패트롤 · 스폰 offset ~11 |
| Pink / Caster | `shooting_enemy.tscn` | 110 | 25 | 상단 체공 · 원형 다연발 탄막(5링×20) · `enemy_caster.svg` |
| Awl / Kamikaze | `kamikaze_enemy.tscn` | 70 | 15 | 3마리 V로 하강·조준 → 차지 시 V에서 각자 독립 돌진 · 투사체 없음 |
| Bomb | `bomb_enemy.tscn` | 140 | 20 | 느린 하강 · 고체력 · 근접 시 2초 3회 적색 점멸 후 1.5× 자폭 · `enemy_bomb.svg` |

베이스 `enemies/enemy.tscn`: 네온 레이어, 전투/VFX, `TargetingComponent`, `EnemyShootComponent`, `EnemyModifierFactory`, XP 드롭.

## Enemy 베이스 동작

- `no_health` → 점수 + XP + `queue_free`
- Hurt VFX/SFX · 카미카제 Hitbox free
- **이동:** `Node2D` + `MoveComponent.translate` (CharacterBody/`move_and_slide` 없음). 기본 진행 **+Y**.

## EnemyGenerator

- **Green:** `handle_drone_formation_spawn` — 오프셋 배열 길이만큼 동시 스폰(기본 5)
- **Awl:** `handle_awl_formation_spawn` — 항상 3마리 V
- Yellow / Pink / Bomb: 단발 스폰
- Pink는 score > 50 후 활성화
- 베이스·Drone·Striker는 `EnemyShootComponent`로 조준 사격 (Striker 예: `burst_count` 3 · `shot_count` 5)

## Caster 상단 체공 · 원형 탄막

- `CasterHoverComponent`: 진입 후 `hover_y`(기본 56)에 고정, 좌우 패트롤만
- `RadialBarrageShootComponent`: 주기마다 링 5회 × 20발 (링마다 소각 회전), `base_enemy_projectile`
- 레거시 상태머신 / `EnemyShootComponent`는 `_enter_tree`에서 제거

## Awl 자폭 (Kamikaze)

- 스폰: 3마리 V (`handle_awl_formation_spawn`) — 하강·조준 구간만 V 유지
- **차지 시작 순간** V 슬롯에 스냅한 뒤, 각자 기존처럼 자기 위치→플레이어 락온 방향으로 독립 돌진
- 투사체 없음

## Bomb 근접 자폭

`BombProximityFuseComponent`:

- 느린 하강 `(0, 16)`, HP 140
- 플레이어가 `trigger_radius`(72) 안이면 정지 → **2초간 빨간 점멸 3회** → 자폭
- 폭발 VFX scale **1.5×**, 피해 반경 `base_explosion_radius(40) * 1.5`
- 투사체 없음

## Drone 대각 편대

`FormationDiagonalMoveComponent`: 공유 클록 대각 + X ping-pong. `handle_drone_formation_spawn`은 `add_child` 이후 `setup_formation` 호출(viewport 안전).

## EnemyModifierFactory

HEALTH / MOVE_SPEED / ACTION_RATE (+ `EnemyShootComponent` / `RadialBarrageShootComponent` 주기).
