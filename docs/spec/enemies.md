# 적

## 타입 (생성기 기준)

| 코드명 | 씬 | HP | 점수 | 특징 |
|--------|-----|-----|------|------|
| Green | `normal_enemy.tscn` | 30 | 5 | 직선 하강 `(0, 40)` |
| Yellow | `moving_enemy.tscn` | 60 | 10 | 랜덤 ±20 X + BorderBounce |
| Pink | `shooting_enemy.tscn` | 60 | 20 | 상태머신 + 곡선탄 |

베이스 `enemies/enemy.tscn`: 네온 레이어 스프라이트, 전투/VFX 스택, `TargetingComponent`, `EnemyModifierFactory`.

## Enemy 베이스 동작

- `no_health` → 점수 가산 + `queue_free` (+ DestroyedComponent 폭발)
- Hurt → scale / flash / shake / hit SFX
- 몸 Hitbox가 플레이어 Hurtbox에 닿으면 `queue_free` (카미카제)

## EnemyGenerator

- 스폰 Y = `-16`, X 랜덤(마진 8)
- 속도식: `time_offset / (0.5 + score*0.01) + rand(0.25, 0.5)`
  - Green offset 1 · Yellow 5 · Pink 10
- 타이머 초기: Green 3s / Yellow 5s / Pink 8s
- Pink는 시작 시 `PROCESS_MODE_DISABLED`, **score > 50**이면 활성화
- 스폰 직전 `enemy.augment_registry` 주입

## Pink 상태머신

`MoveDown`(3s, Y=20) → `MoveSide`(3s, ±X+bounce) → 종료 시 `Pause` + `fire()` → 다시 MoveDown  
`fire()`: `curve_projectile.tscn` 스폰

## EnemyModifierFactory

스폰 `_ready`에서:

1. 로컬 + 레지스트리 `EnemyStatModifier` (HEALTH / MOVE_SPEED / ACTION_RATE)
2. `behavior_components` 인스턴스 deferred 부착
3. ACTION_RATE → 모든 `TimedStateComponent.duration` 나눗셈
