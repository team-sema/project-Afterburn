# 컴포넌트 시스템

엔티티는 스크립트 한 덩어리가 아니라 **Area2D/Node 자식 컴포넌트** 조합이다. `class_name`으로 에디터 커스텀 타입으로 붙인다.

## 이동 · 경계

| 클래스 | 역할 |
|--------|------|
| `MoveComponent` | `velocity * velocity_multiplier`를 actor에 적용 |
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
| `HurtComponent` | hurt → Stats에서 damage 차감 |
| `DestroyedComponent` | `no_health` → 이펙트 스폰 + free |
| `ScoreComponent` | `GameStats.score`에 가산 |

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
| `PlayerAugmentApplier` | 레지스트리 → 이동/연사/데미지 배수 |
| `EnemyModifierFactory` | 스폰 시 적 스탯·행동 컴포넌트 적용 |
| `EnemyAugmentGrantComponent` | 수동으로 적 오그먼트 grant *(씬 미연결)* |
| `TargetingComponent` | `"player"` 그룹 타깃 |
| `CounterShotComponent` | 피격/사망 시 반격 탄 (`augment_behaviors/`) |
