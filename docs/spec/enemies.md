# 적

## 타입 (생성기 기준)

| 코드명 | 최소 Threat | 씬 | HP | 점수 | 특징 |
|--------|-------------|-----|-----|------|------|
| Green / Drone | 1 | `normal_enemy.tscn` | 20 | 5 | 편대 대각 하강 |
| Yellow / Striker | 1 | `moving_enemy.tscn` | 50 | 10 | 직하강 → 중앙 정지 → 좌우 패트롤 |
| Awl / Kamikaze | 2 | `kamikaze_enemy.tscn` | 70 | 15 | 3마리 V로 하강·조준 → 차지 시 V에서 각자 독립 돌진 · 투사체 없음 |
| Bomb | 2 | `bomb_enemy.tscn` | 140 | 20 | 느린 하강 · 고체력 · 근접 시 2초 3회 적색 점멸 후 1.5× 자폭 · `enemy_bomb.svg` |
| Pink / Caster | 3 | `shooting_enemy.tscn` | 110 | 25 | 상단 체공 · 원형 다연발 탄막(5링×20) · `enemy_caster.svg` |

베이스 `enemies/enemy.tscn`: 네온 레이어, 전투/VFX, `TargetingComponent`, `EnemyShootComponent`, `EnemyModifierFactory`, XP 드롭.

## Enemy 베이스 동작

- `no_health` → 점수 + XP + `queue_free`
- Hurt VFX/SFX · 플레이어 접촉 시 피해만 주고 적은 유지
- **이동:** `Node2D` + `MoveComponent.translate` (CharacterBody/`move_and_slide` 없음). 기본 진행 **+Y**.

## EnemyGenerator

- `EnemySpawnSet` 리소스가 적 씬, 최소 Threat, `EnemySpawnPattern` 리소스를 정의한다.
- 패턴 리소스가 편대 오프셋과 이동 파라미터 및 생성 동작을 소유한다. 새 Formation은 Generator 분기 없이 새 패턴 Resource로 추가한다.
- 생성기는 현재 Threat 이하의 스폰 세트만 후보로 선별하고 그중 하나를 균등하게 선택한다.
- **Green:** Drone 편대 — 오프셋 배열 길이만큼 동시 스폰(기본 5)
- **Awl:** 3마리 V 편대
- Yellow / Pink / Bomb: 단발 스폰
- 베이스·Drone·Striker는 `EnemyShootComponent`로 조준 사격
- **초반(Threat 1) 사격 압력** — 투사체를 쏘는 Threat 1 적은 아래 값을 쓴다. Kamikaze·Bomb은 투사체가 없고, Caster는 Threat 3이라 초반 압력에 포함되지 않는다

| 적 | `fire_interval` | 볼리 | 발수 | 탄속 | `initial_delay` |
|---|---|---|---|---|---|
| Drone (5기 편대) | 4.5 | 1 | 1 | 105 | 1.5 |
| Striker | 4.5 | 2 (`burst_interval` 0.15) | 5 (`spread` 15°) | 80 | 1.5 |

- 이후 난이도는 적 오그먼트 `ACTION_RATE`가 `fire_interval`·`burst_interval`을 나눠 올리고, 상위 Threat 적이 합류하며 오른다. 탄속에는 배율이 없다

## Caster 상단 체공 · 원형 탄막

- `CasterHoverComponent`: 진입 후 `hover_y`(기본 56)에 고정, 좌우 패트롤만
- `RadialBarrageShootComponent`: 주기마다 링 5회 × 20발 (링마다 소각 회전), `base_enemy_projectile`
- 레거시 상태머신 / `EnemyShootComponent`는 `_enter_tree`에서 제거

## Awl 자폭 (Kamikaze)

- 스폰: `AwlFormationSpawnPattern`이 3마리 V를 구성하며 하강·조준 구간만 편대를 유지
- **차지 시작 순간** V 슬롯에 스냅한 뒤, 각자 기존처럼 자기 위치→플레이어 락온 방향으로 독립 돌진
- 투사체 없음

## Bomb 근접 자폭

`BombProximityFuseComponent`:

- 느린 하강 `(0, 16)`, HP 140
- 플레이어가 `trigger_radius`(60) 안이면 정지 → **2초간 빨간 점멸 3회** → 자폭
- 신관 무장과 적색 점멸이 시작되면 반투명 범위 프리뷰 표시
- 폭발 판정·VFX 최대 링·범위 프리뷰 반경은 모두 `base_explosion_radius(40) * 1.5 = 60px`
- `blast_damage` **1** (플레이어 피격은 이벤트당 항상 1)
- `고속 기폭 장치` 적 증강 활성 시 무장 시간 `2.0초 / 1.5 ≈ 1.33초`
- 투사체 없음

## Drone 대각 편대

`FormationDiagonalMoveComponent`: 공유 클록 대각 + X ping-pong. `DroneFormationSpawnPattern`이 편대 구성과 이동 설정을 주입한다.

## EnemyModifierFactory

HEALTH / MOVE_SPEED / ACTION_RATE (+ `EnemyShootComponent` / `RadialBarrageShootComponent` 주기).

## 보스 플래그 (`is_boss`)

- `Enemy.is_boss == true`이면 `bosses` 그룹에 들어가며, 시설 **대형 표적 해석기**(`BOSS_DAMAGE_MULT`) 피해 배율 대상이 된다
- 현재 스폰 세트에는 보스 적을 넣는 콘텐츠가 **없음** (플래그·배율만 구현)
