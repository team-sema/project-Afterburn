# 컴포넌트 시스템

엔티티는 스크립트 한 덩어리가 아니라 **Area2D/Node 자식 컴포넌트** 조합이다. `class_name`으로 에디터 커스텀 타입으로 붙인다.

## 이동 · 경계

| 클래스 | 역할 |
|--------|------|
| `MoveComponent` | 레거시 `velocity` 또는 `MovementIntent`를 받아 actor에 실제 이동 적용 |
| `MovementController` | `MovementSequence`의 현재 Step과 런타임 상태를 소유하고 Intent를 `MoveComponent`에 전달 |
| `MovementSequence` | 설정 전용 `MovementStep` 배열 Resource. 여러 적이 같은 Resource를 안전하게 공유 |
| `Linear/Sine/MoveToPosition/Wait/HomingMovementStep` | 조합 가능한 범용 이동 단계 |
| `HorizontalPatrolMovementStep` | 뷰포트 좌우 경계에서 반사하는 범용 순찰 단계 |
| `BoundedDiagonalMovementStep` | 편대 반경을 고려해 뷰포트 좌우에서 반사하는 범용 대각 이동 단계 |
| `FormationSlot` / `FormationLayout` | 에디터에서 배치하는 명시적 슬롯과 검증·미리보기 전용 편대 모양 Scene |
| `FormationController` | Scene 기반 슬롯 매핑, 단일 편대 중앙 이동, 멤버 위치·이탈·해제 후 개별 Sequence 전환 |
| `RadialBarrageShootComponent` | 원형 다연발 링 탄막 |
| `BombProximityFuseComponent` | 근접 신관 → 적색 점멸 → 자폭. 판정·VFX·반투명 프리뷰가 동일 radius 사용 |
| `BombBlastPreview` | Bomb 신관 무장 중 자폭 판정 범위를 옅은 원과 외곽선으로 표시 |

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
| `HurtComponent` | hurt → 피해 처리 · 공용 무적 타이머와 반투명 표시 · 플레이어 기본 0.6초 무적 |
| `ShieldComponent` | 버퍼 HP · **시작 최대 1** · 피해는 실드 우선·초과분은 선체 · 미만 시 충전 게이지 → `restore_shield(1)` · `notify_hit` 시 게이지 리셋 |
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
| `EnemySpawner` | 선택된 `EncounterPreset`만 실제 생성하고 의존성·Encounter ID를 트리 진입 전에 주입. 단일 적도 동일한 `FormationController` 생명주기를 사용 |
| `EncounterPreset` / `EncounterMember` | Layout, 편대·개별 Sequence, 슬롯별 적, 등장 지연, 반전, 편대 해제 조건을 조합하는 설정 Resource |
| `EncounterPool` / `EncounterPoolEntry` / `ThreatWeight` | 전체 라이브 Encounter 로스터와 Threat별 선택 weight를 한 리소스에서 관리. 마지막 정의 Threat 이후에는 마지막 weight 유지 |
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
| `PlayerAugmentApplier` | 설치된 모듈 → 이동 배수(+부스터) · 전역 연사/피해(레거시 STAT). `WEAPON_TRAIT`는 loadout trait API |
| `ShipFacilityApplier` | `FacilityModuleEffect` Kind 합산 → 무기 피해·보스 피해·이동·선체·수집·실드·XP·충전속도 · 버프/부스터 컨트롤러 refresh |
| `ShipCombatBuffController` | 과충전(주기) · 비상 출력(선체 피격) → temp 피해 배율 |
| `EngineBoostComponent` | `engine_boost`(Shift) 액티브 이속 버프 · 쿨다운 시그널 |
| `EnemyModifierFactory` | 스폰 시 적 스탯·행동 컴포넌트 적용 |
| `EnemyAugmentGrantComponent` | 수동으로 적 오그먼트 grant *(씬 미연결)* |
| `TargetingComponent` | `"player"` 그룹 타깃 |
| `EnemyShootComponent` | 적 기본 조준 사격 · `fire_interval` + **`burst_count`/`burst_interval`** 연발 · 기본 탄 `base_enemy_projectile` |
| `EnemyFireVolumeBoostComponent` | 위기: 탄수·스프레드 증가 (`augment_behaviors/`) |
| `CounterShotComponent` | 피격/사망 반격 탄 *(풀에서 제외, 레거시)* |
