# 오그먼트

## Resource 모델

| 타입 | 필드 |
|------|------|
| `PlayerAugment` / `EnemyAugment` | `augment_id`, `display_name`, `description`, `stat_modifiers[]`, `behavior_components[]` |
| `PlayerStatModifier.Stat` | `MOVE_SPEED`, `FIRE_RATE`, `WEAPON_DAMAGE` |
| `EnemyStatModifier.Stat` | `HEALTH`, `MOVE_SPEED`, `ACTION_RATE` |

## 현재 풀 (World 익스포트)

### 플레이어 (×1.2)

| ID | 표시명 | 효과 |
|----|--------|------|
| `player_move_speed_boost_1_2` | Overcharged Thrusters | MOVE_SPEED |
| `player_fire_rate_boost_1_2` | Accelerated Capacitors | FIRE_RATE |
| `player_weapon_damage_boost_1_2` | Overcharged Payload | WEAPON_DAMAGE |

### 적

| ID | 표시명 | 효과 |
|----|--------|------|
| `enemy_health_boost_1_2` | Enemy Reinforcement | HEALTH ×1.2 (이후 스폰) |
| `enemy_move_speed_boost_1_2` | Accelerated Hostiles | MOVE_SPEED ×1.2 |
| `enemy_counter_shot_on_hit` | Retaliation Protocol | `CounterShotComponent` 부착 |

## 트리거 · 컨트롤러

### ScoreAugmentOfferTrigger (World 오버라이드)

- `first_offer_score = **10**` (스크립트 기본 50)
- `score_interval = **100**` (스크립트 기본 50)
- `score >= next`이면 큐에 쌓고 임계치를 interval만큼 전진

### AugmentOfferController

- 시그널: `offer_started`, `offer_completed(player, enemy)`
- 페이즈: PLAYER → ENEMY
- `choices_per_offer = 3` (풀 크기 ≥ 3 필요)
- 플레이어 선택 즉시 registry 반영 → 적 선택 후 UI 종료

### UI

- `AugmentSelectionOverlay` — `open_choices` / `transition_choices` / `close_with_result`
- `AugmentBreakpointIntro` — AnimationPlayer `"reveal"`

## 레지스트리

`PlayerAugmentRegistry` / `EnemyAugmentRegistry`:

- `add_augment` · `get_active_augments` · `get_stack_count` · `clear_augments`
- 시그널: `augment_added`, `augments_cleared`

> `clear_augments()`는 현재 **호출처 없음**. 새 World 인스턴스가 빈 상태로 시작.

## CounterShotComponent

- `Trigger.ON_HIT`(기본) / `ON_DEATH`
- 부모 Enemy + TargetingComponent 필요
- 기본 스프레드 5° · 속도 200
