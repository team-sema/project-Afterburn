# 컴포넌트 시스템

엔티티는 스크립트 한 덩어리가 아니라 **Area2D/Node 자식 컴포넌트** 조합이다. `class_name`으로 에디터 커스텀 타입으로 붙인다.

## 이동 · 경계

| 클래스 | 역할 |
|--------|------|
| `MoveComponent` | `velocity * velocity_multiplier`를 actor에 `translate` |
| `FormationDiagonalMoveComponent` | 공유 시각 기준 직선 대각 편대 이동 (MoveComponent process off). `setup_formation`은 트리 진입 후(또는 deferred)에 viewport를 읽음 |
| `StrikerDivePatrolComponent` | 직하강 → 화면 중앙 비율에서 정지 → 좌우 velocity 패트롤 |
| `KamikazeAimChargeComponent` | 하강 → 조준(정지) → 락온 돌진 (MoveComponent velocity) |
| `CasterHoverComponent` | 상단 hover_y 체공 + 좌우 패트롤 |
| `RadialBarrageShootComponent` | 원형 다연발 링 탄막 |
| `BombProximityFuseComponent` | 근접 신관 → 적색 점멸 → 1.5× 자폭(VFX+AOE) |

| `MoveInputComponent` | `ui_*`/WASD → MoveComponent (`MoveStats.speed`) |
| `MoveStats` | 이동 속도 Resource |
| `MoveLeftOrRightComponent` | 상태 진입 시 ±X 속도 |
| `PositionClampComponent` | 뷰포트 안 클램프 |
| `BorderBounceComponent` | 화면 가장 X 속도 반사 |
| `FreeOffscreenComponent` | 화면 밖이면 `queue_free` |

## 전투 · 생존

| 클래스 | 역할 |
|--------|------|
| `StatsComponent` | HP + `health_changed` / `no_health` |
| `HurtboxComponent` | 피격 Area2D · `hurt(hitbox)` · 무적 시 shape off |
| `HitboxComponent` | 공격 Area2D · `damage` · `hit_hurtbox` |
| `HurtComponent` | hurt → (실드가 있으면 게이트 판정 먼저) Stats에서 damage 차감 |
| `ShieldComponent` | 선체와 분리된 실드 자원 · 실드 ≥ 1이면 피해 이벤트 전체 흡수 · `restore_shield` / `add_shield` |
| `DestroyedComponent` | `no_health` → 이펙트 스폰 + free |
| `ScoreComponent` | `GameStats.score`에 가산 |
| `ExperienceDropComponent` | 적 사망 시 경험치 오브 스폰 |
| `ExperienceCollectorComponent` | 플레이어 XP 수집 반경 제공 |

## 연출 · 스폰

| 클래스 | 역할 |
|--------|------|
| `ScaleComponent` | 펀치 스케일 트윈 |
| `ShakeComponent` | 위치 셰이크 |
| `FlashComponent` | 화이트 플래시 머티리얼 |
| `SpawnerComponent` | PackedScene 인스턴스 |
| `OnetimeAnimatedEffect` | 애니 종료 시 free |
| `VariablePitchAudioStreamPlayer` | 피치 랜덤 SFX |

## 상태머신

| 클래스 | 역할 |
|--------|------|
| `StateComponent` | enable/disable + `entering`/`state_finished` 등 |
| `StateMachineComponent` | State 자식 중 하나만 활성 |
| `TimedStateComponent` | duration 후 `state_finished` *(파일명 typo: `timed_state_componoent.gd`)* |

## 오그먼트 · AI 보조

| 클래스 | 역할 |
|--------|------|
| `PlayerAugmentApplier` | 설치된 모듈 → 이동/연사/데미지 배수. `WEAPON_TRAIT`는 loadout trait API로 전달(전투 효과 스캐폴드) |
| `ShipFacilityApplier` | 설치된 시설 효과 모듈 → **장착 무기 공통 피해**·이동속도·최대 선체·수집 반경·최대 실드 (격납고 탄약 경로 없음) |
| `EnemyModifierFactory` | 스폰 시 적 스탯·행동 컴포넌트 적용 |
| `EnemyAugmentGrantComponent` | 수동으로 적 오그먼트 grant *(씬 미연결)* |
| `TargetingComponent` | `"player"` 그룹 타깃 |
| `EnemyShootComponent` | 적 기본 조준 사격 · `fire_interval` + **`burst_count`/`burst_interval`** 연발 · 기본 탄 `base_enemy_projectile` |
| `EnemyFireVolumeBoostComponent` | 위기: 탄수·스프레드 증가 (`augment_behaviors/`) |
| `CounterShotComponent` | 피격/사망 반격 탄 *(풀에서 제외, 레거시)* |
