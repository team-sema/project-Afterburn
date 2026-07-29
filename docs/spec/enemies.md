# 적

## 타입 (생성기 기준)

| 코드명 | 씬 | HP | 점수 | 특징 |
|--------|-----|-----|------|------|
| Green | `normal_enemy.tscn` | 30 | 5 | 직선 하강 `(0, 46)` · 기본 조준 사격 |
| Yellow | `moving_enemy.tscn` | 60 | 10 | 랜덤 ±23 X + BorderBounce · 기본 조준 사격 |
| Pink | `shooting_enemy.tscn` | 60 | 20 | 상태머신(이동) · 더 빠른 기본 조준 사격 |

베이스 `enemies/enemy.tscn`: 네온 레이어 스프라이트, 전투/VFX 스택, `TargetingComponent`, `EnemyShootComponent`, `EnemyModifierFactory`, 경험치 오브 드롭.

## Enemy 베이스 동작

- `no_health` → 점수 가산 + 경험치 오브 1개 드롭 + `queue_free` (+ DestroyedComponent 폭발)
- Hurt → scale / flash / shake / hit SFX
- 몸 Hitbox가 플레이어 Hurtbox에 닿으면 `queue_free` (카미카제)
- **기본 사격:** `EnemyShootComponent` — 플레이어 조준, 약 2초 주기(`curve_projectile`, speed 100). Pink는 1.6초·속도 110으로 튜닝.

## EnemyGenerator

- 스폰 Y = `-16`, X 랜덤(마진 8)
- 속도식: `time_offset / (0.5 + score*0.01) + rand(0.25, 0.5)`
  - Green offset 1 · Yellow 5 · Pink 10
- 타이머 초기: Green 3s / Yellow 5s / Pink 8s
- Pink는 시작 시 `PROCESS_MODE_DISABLED`, **score > 50**이면 활성화
- 스폰 직전 `enemy.augment_registry` 주입

## Pink 상태머신

`MoveDown`(2.5s, Y=23) → `MoveSide`(2.5s, ±X 23 + bounce) → `Pause`(2.5s) → 다시 MoveDown  
사격은 상태와 독립적으로 `EnemyShootComponent`가 담당.

## EnemyModifierFactory

스폰 `_ready`에서:

1. 로컬 + 레지스트리 `EnemyStatModifier` (HEALTH / MOVE_SPEED / ACTION_RATE)
2. `behavior_components` 인스턴스 deferred 부착
3. ACTION_RATE → 모든 `TimedStateComponent.duration` 나눗셈 + `EnemyShootComponent` 발사 주기 단축
