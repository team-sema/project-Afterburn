# 적

## 타입 (생성기 기준)

| 코드명 | 씬 | HP | 점수 | 특징 |
|--------|-----|-----|------|------|
| Green / Drone | `normal_enemy.tscn` | 20 | 5 | 편대 대각 하강 · 스폰 offset ~5 |
| Yellow / Striker | `moving_enemy.tscn` | 50 | 10 | 직하강 → 중앙 정지 → 좌우 패트롤 · 스폰 offset ~11 |
| Pink | `shooting_enemy.tscn` | 60 | 20 | 상태머신(이동) · 기본 조준 사격 |
| Awl / Kamikaze | `kamikaze_enemy.tscn` | 70 | 15 | 투사체 없음 · 2s 하강 → 2s 조준 → 블래스터 속도(200)로 락온 돌진 · `enemy_awl.svg` |

베이스 `enemies/enemy.tscn`: 네온 레이어, 전투/VFX, `TargetingComponent`, `EnemyShootComponent`, `EnemyModifierFactory`, XP 드롭.

## Enemy 베이스 동작

- `no_health` → 점수 + XP + `queue_free`
- Hurt VFX/SFX · 카미카제 Hitbox free
- **이동:** `Node2D` + `MoveComponent.translate` (CharacterBody/`move_and_slide` 없음). 기본 진행 **+Y**.

## EnemyGenerator

- **Green:** `handle_drone_formation_spawn` — 오프셋 배열 길이만큼 동시 스폰(기본 5). 공유 origin/start_time/속도·각도
- Yellow/Pink/Kamikaze: 단발 스폰
- Inspector(Drone Formation): scene, offsets, `drone_forward_speed`, `drone_dive_angle_degrees`
- Kamikaze: `kamikaze_spawn_time_offset` (~8), 첫 스폰 ~7s
- Pink는 score > 50 후 활성화

## Awl 자폭 (Kamikaze)

`KamikazeAimChargeComponent`:

1. **DESCEND** (~2s): `velocity = (0, descend_speed)`
2. **AIM** (~2s): 정지, Anchor를 플레이어 방향으로 회전
3. **CHARGE**: 발사 순간의 플레이어 좌표를 고정 → `velocity = dir * 200` (블래스터와 동일)

`EnemyShootComponent`는 `_enter_tree`에서 즉시 제거 (발사 없음).

## Drone 대각 편대

`FormationDiagonalMoveComponent` (사인/Path2D/FormationController 없음):

```
direction = (sin(angle), cos(angle))  # angle from +Y toward +X
pos = origin + offset + direction * speed * speed_scale * elapsed
```

- 기본 `dive_angle_degrees = 10` (좌→우로 내려옴)
- 활성 시 MoveComponent process off (절대 위치 단일 writer)
- 편대원 사망해도 타 멤버 수식 불변

## Pink 상태머신

`MoveDown` → `MoveSide` → `Pause`. 사격은 `EnemyShootComponent`.

## EnemyModifierFactory

HEALTH / MOVE_SPEED / ACTION_RATE + behavior 부착.
