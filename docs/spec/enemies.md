# 적

## 타입 (MainEncounterPool 기준)

| 코드명 | 최소 Threat | 씬 | HP | 점수 | 특징 |
|--------|-------------|-----|-----|------|------|
| Green / Drone | 1 | `normal_enemy.tscn` | 20 | 5 | 편대 대각 하강 · Striker 호위 편대에도 등장 |
| Yellow / Striker | 1 | `moving_enemy.tscn` | 50 | 10 | 마름모 편대 최후방 · 맵 1/3 하강 후 좌우 패트롤 |
| Awl / Kamikaze | 2 | `kamikaze_enemy.tscn` | 70 | 15 | 3마리 V로 하강·조준 → 차지 시 V에서 각자 독립 돌진 · 투사체 없음 |
| Bomb | 2 | `bomb_enemy.tscn` | 140 | 20 | 느린 하강 · 고체력 · 근접 시 2초 3회 적색 점멸 후 1.5× 자폭 · `enemy_bomb.svg` |
| Interceptor | 2 | `interceptor_enemy.tscn` | 20 | 5 | 2~3기 편대 · 좌↔우 랜덤 횡단 · 0.55초 진입 경고 · 기체보다 빠른 forward 탄 · `enemy_interceptor.svg` |
| Pink / Caster | 3 | `shooting_enemy.tscn` | 110 | 25 | 상단 체공 · 원형 다연발 탄막(5링×20) · `enemy_caster.svg` |
| Sniper | 3 | `sniper_enemy.tscn` | 95 | 25 | 상단 고정 · 4초 Cone 조준 · 0.5초 레이저 · 2.5초 쿨다운 반복 · `enemy_sniper.svg` |

베이스 `enemies/enemy.tscn`: 네온 레이어, 전투/VFX, `TargetingComponent`, `EnemyShootComponent`, `EnemyModifierFactory`, XP 드롭.

## Enemy 베이스 동작

- `no_health` → 점수 + XP + `queue_free`
- Hurt VFX/SFX · 플레이어 접촉 시 피해만 주고 적은 유지
- **이동:** `Node2D` + `MovementSequence` → `MovementController` → `MoveComponent.translate` (CharacterBody/`move_and_slide` 없음). Sequence가 없는 기존 객체는 `MoveComponent.velocity` 경로를 유지한다.

## EnemyGenerator

- 생성기는 4초 + 0~0.5초 지터의 타이머와 현재 Threat만 관리하고, `main_encounter_pool.tres`에 선택을 요청한다.
- `MainEncounterPool`이 현재 Threat에서 weight가 0보다 큰 `EncounterPreset` 전체를 대상으로 weighted random을 정확히 한 번 수행한다.
- `EncounterPreset`은 FormationLayout Scene, 편대·개별 MovementSequence, 멤버와 슬롯, 등장·해제 조건을 조합하며 `EnemySpawner`가 실제 적을 생성한다.
- Striker/Bomb/Caster/Sniper 중 Bomb·Caster·Sniper는 `SingleFormation`의 Slot0을 사용하는 1슬롯 Encounter이며, 생성 직후 편대를 해제해 기존 개별 MovementSequence를 그대로 실행한다.
- **Green:** Drone 편대 — `HorizontalFormation`의 명시적 슬롯 5개에 동시 스폰
- **Yellow 호위:** `striker_drone_diamond` — `DiamondFormation` 최후방(Slot0) Striker + 전방 3슬롯(Slot1–3) Drone. 하단 팁(Slot4)은 비움
- **Awl:** 3마리 V 편대
- **Interceptor:** `interceptor_pair`(Threat 2+) / `interceptor_trio`(Threat 3+)만 사용하며 단독 Encounter는 없음
- Pink / Bomb / Caster: `caster_single` / `bomb_single`. Sniper는 `tanker_guard_sniper` 후방 슬롯으로만 등장
- 베이스·Drone·Striker는 `EnemyShootComponent`로 조준 사격
- **초반(Threat 1) 사격 압력** — 투사체를 쏘는 Threat 1 적은 아래 값을 쓴다. Kamikaze·Bomb은 투사체가 없고, Caster는 Threat 3이라 초반 압력에 포함되지 않는다

| 적 | `fire_interval` | 볼리 | 발수 | 탄속 | `initial_delay` |
|---|---|---|---|---|---|
| Drone (5기 편대 / 호위 3기) | 4.5 | 1 | 1 | 105 | 1.5 |
| Striker (호위 편대) | 4.5 | 2 (`burst_interval` 0.15) | 5 (`spread` 15°) | 80 | 1.5 |

- 이후 난이도는 적 오그먼트 `ACTION_RATE`가 `fire_interval`·`burst_interval`을 나눠 올리고, 상위 Threat 적이 합류하며 오른다. 탄속에는 배율이 없다

### MainEncounterPool 초기 weight

| Encounter | Threat 1 | Threat 2 | Threat 3+ |
|---|---:|---:|---:|
| `drone_formation` | 6 | 6 | 6 |
| `striker_drone_diamond` | 6 | 6 | 6 |
| `awl_formation` | 0 | 6 | 6 |
| `bomb_single` | 0 | 6 | 6 |
| `caster_single` | 0 | 0 | 4 |
| `tanker_guard_sniper` | 0 | 1 | 4 |
| `x9_drone_down` | 0 | 0 | 3 |
| `x9_caster_drone_orbit` | 0 | 0 | 1 |
| `v7_drone_down` | 0 | 0 | 2 |
| `interceptor_pair` | 0 | 2 | 2 |
| `interceptor_trio` | 0 | 0 | 1 |

테스트·웨폰 랩용 추가 드론 하강 프리셋(풀 weight 없음): `v3_drone_down`, `v5_drone_down`, `inverted_v3_drone_down`, `inverted_v5_drone_down`, `inverted_v7_drone_down`, `x5_drone_down`, `drone_triangle_formation`.

Threat 3 기존 합 38에 Interceptor pair/trio `2/1`을 더해 총 weight는 41이다. Pair는 Threat 2부터, Trio는 Threat 3부터 등장한다.

## Interceptor 고속 공격 패스

- `interceptor_enemy.tscn`은 `normal_enemy.tscn`을 상속하므로 Drone과 HP(20)·점수·XP 보상값을 공유한다.
- `interceptor_pair`는 전용 36px 가로 2기 슬롯, `interceptor_trio`는 기존 `V3Formation` 슬롯을 사용한다.
- `EnemySpawner`가 `ForwardAttackRun` Encounter를 좌→우 / 우→좌 중 랜덤 횡단으로 배치한다. 스폰 Y는 VisibleRect 높이의 약 16~38% 상단 밴드에 두어 깊은 후방(화면 밖 상단) 전용 진입을 피한다.
- `start_delay=0.55` 동안 횡단 진입 레인에 `EntryWarningComponent` 경고를 표시한다.
- `ForwardAttackRunMovementStep`: 편대 루트를 횡단 방향으로 먼저 회전한 뒤, 설정된 local forward 축으로만 210px/s 이동한다. 화면 clamp·bounce·sine·strafe·재추적은 없다.
- 편대 루트 회전이 슬롯 위치와 각 멤버 회전에 함께 적용되므로 형태를 유지하면서 기수와 실제 이동 방향이 일치한다.
- `EnemyShootComponent`의 visible-entry fire gate가 기체 중심이 VisibleRect에 들어온 뒤에만 1.35초 사격 창을 연다. 2발 burst, 0.12초 burst 간격, 0.7초 재공격 간격이며 탄환은 플레이어 조준이 아니라 기체 forward로 **300px/s**(기체 210보다 빠름) 발사한다.
- 생존 기체는 횡단 방향 DespawnArea 밖으로 그대로 이탈한다. 이 경로는 `no_health`를 발생시키지 않으므로 점수·XP·처치 보상이 없고, 실제 파괴 시에만 기존 보상이 발생한다.

## Caster 상단 체공 · 원형 탄막

- `caster_entry_patrol.tres`: `MoveToPositionStep`으로 y=56에 진입한 뒤 `HorizontalPatrolMovementStep` 실행
- `RadialBarrageShootComponent`: 주기마다 링 5회 × 20발 (링마다 소각 회전), `base_enemy_projectile`
- 레거시 상태머신 / `EnemyShootComponent`는 `_enter_tree`에서 제거

## Sniper 원거리 저격

- `sniper_entry_hold.tres`: `MoveToPositionStep`(y=48) → `HoldPositionMovementStep`으로 포지션 고정
- `SniperAttackComponent`: AIMING(4.0s, 플레이어 지속 추적 + Cone 축소) → FIRING(0.5s 월드 고정 레이저) → COOLDOWN(2.5s) 반복
- 재발사 시 재포지셔닝 없음. `EnemyShootComponent`는 `_enter_tree`에서 제거
- Encounter: `tanker_guard_sniper` — 전방 Tanker(`bottom_inner`) + 후방 Sniper(`center`). `tanker_guard_entry_hold`로 y=48 상단 체공 후 정지. 편대 유지 중 조준·사격

## Awl 자폭 (Kamikaze)

- 스폰: `awl_charge_formation.tres`가 `V3Formation` 슬롯 3개를 사용하며 하강 구간만 편대를 유지
- **하강 완료 순간** V에서 분리한 뒤, 각자 3초 조준(차징) → 플레이어 락온 방향으로 독립 돌진
- 투사체 없음

## Bomb 근접 자폭

`BombProximityFuseComponent`:

- `bomb_straight_down.tres`의 `LinearMovementStep`으로 느린 하강 `(0, 16)`, HP 140
- 플레이어가 `trigger_radius`(60) 안이면 정지 → **2초간 빨간 점멸 3회** → 자폭
- 신관 무장과 적색 점멸이 시작되면 반투명 범위 프리뷰 표시
- 폭발 판정·VFX 최대 링·범위 프리뷰 반경은 모두 `base_explosion_radius(40) * 1.5 = 60px`
- `blast_damage` **1** (플레이어 피격은 이벤트당 항상 1)
- `고속 기폭 장치` 적 증강 활성 시 무장 시간 `2.0초 / 1.5 ≈ 1.33초`
- 투사체 없음

## Drone 대각 편대

`drone_straight_formation.tres`가 `HorizontalFormation`과 `formation_drone_diagonal.tres`를 조합한다. 편대 중앙의 단일 `MovementController`가 일정한 대각 이동을 계산하고, `FormationController`가 각 Drone을 슬롯에 유지한다.

`drone_entry_scatter.tres`는 세로 줄로 모인 뒤 `drone_entry_gather`(뷰포트 y≈0.2)에서 즉시 해제하고, 각 개체가 하위 180° 중 랜덤 직선으로 산개한다.

`drone_zigzag_formation.tres` / `drone_zigzag_mirrored.tres`는 `zigzag.tres`의 `BoundedDiagonalMovementStep`을 쓴다. 속도와 각도가 일정한 대각선으로 비행하며, VisibleRect가 아닌 더 넓은 MovementArea에서만 방향을 반사하므로 일부 offscreen 이동과 재진입이 가능하다.

`drone_triangle_formation.tres`는 V5에 밑변 중앙 1기를 더한 `Triangle6Formation`(정삼각형 꼭짓점 3 + 변 중점 3)을 쓰며, 이동은 `formation_drone_diagonal.tres`와 같다.

## Striker 드론 호위 (마름모)

`striker_drone_diamond.tres`가 `DiamondFormation`을 쓴다.

- Slot0(`top`, 화면 상단·최후방): Striker
- Slot1–3(`left`/`center`/`right`): Drone 3기 — Striker 전방 방패
- Slot4(`bottom`)는 비움
- 이동: `formation_entry_third_patrol.tres` — 뷰포트 높이 약 1/3까지 직하강한 뒤 `HorizontalPatrolMovementStep`으로 좌우 왕복. 편대는 해제하지 않는다

레거시 `striker_single.tres`는 단일 해제 경로용으로 남기되 `MainEncounterPool`에는 넣지 않는다.

## X9 Caster 궤도

`x9_caster_drone_orbit.tres`가 `X9Formation` + `OrbitFormationBehavior`(중심 슬롯 제외)를 쓴다.

- 이동: `x9_caster_entry_patrol.tres` — 편대 중심을 y=48까지 하강한 뒤 `HorizontalPatrolMovementStep`으로 상단 좌우 패트롤 (추가 하강 없음)
- 중심: Caster, 나머지 8슬롯: Drone 공전

## EnemyModifierFactory

HEALTH / MOVE_SPEED / ACTION_RATE (+ `EnemyShootComponent` / `RadialBarrageShootComponent` / `SniperAttackComponent` 주기).

## 보스 플래그 (`is_boss`)

- `Enemy.is_boss == true`이면 `bosses` 그룹에 들어가며, 시설 **대형 표적 해석기**(`BOSS_DAMAGE_MULT`) 피해 배율 대상이 된다
- 현재 스폰 세트에는 보스 적을 넣는 콘텐츠가 **없음** (플래그·배율만 구현)
