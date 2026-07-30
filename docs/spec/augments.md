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
| `enemy_fire_volume_boost` | 포화 사격 | ACTION_RATE ×1.25 + `EnemyFireVolumeBoostComponent` (탄수·스프레드 증가) |

## 트리거 · 컨트롤러

### AugmentProgressionController

- 플레이어: 경험치 오브 획득 → 요구량 충족 시 HUD에 `AUGMENT READY [C]` (자동 오퍼 없음)
- 입력 `open_augment_offer`(**C**): XP ≥ 요구량일 때만 PLAYER 오퍼 오픈 · 성공 시 XP 차감·레벨+1
- 첫 요구 경험치 `5`, 레벨마다 요구량 `+3`
- 적: 플레이 시간 `60초`마다 ENEMY 오퍼를 큐에 추가
- 플레이어/적 이벤트가 겹치면 도달 순서대로 처리

### AugmentOfferController

- 시그널: `offer_started(offer_type)`, `offer_completed(offer_type)`
- PLAYER와 ENEMY 오퍼는 각각 독립된 단일 선택 단계
- `choices_per_offer = 3` (풀 크기 ≥ 3 필요)
- 선택 즉시 해당 registry에 반영한 뒤 UI 종료
- PLAYER 오퍼 종료 시 함선 기준 `player_resume_clear_radius`(기본 36) 안 `enemy_projectiles` 제거 + resume burst VFX

### UI

- `AugmentSelectionOverlay` — `open_choices` / `close_with_result`
- `AugmentBreakpointIntro` — AnimationPlayer `"reveal"`
- `ProgressionHud` — 플레이어 XP·다음 적 증강 타이머 · 준비 시 `[C]` 힌트
- `PauseOverlay` (`world_shell`) — ESC 수동 일시정지 (설정 메뉴는 미구현)

## 레지스트리

`PlayerAugmentRegistry` / `EnemyAugmentRegistry`:

- `add_augment` · `get_active_augments` · `get_stack_count` · `clear_augments`
- 시그널: `augment_added`, `augments_cleared`

> `clear_augments()`는 현재 **호출처 없음**. 새 World 인스턴스가 빈 상태로 시작.

## EnemyFireVolumeBoostComponent

- 베이스 `EnemyShootComponent`의 `shot_count`에 `extra_shots` 가산(기본 +2)
- `spread_degrees`를 최소 `min_spread_degrees`(기본 18°)로 보장
- ACTION_RATE와 함께 위기 오퍼의 “더 많은 탄환” 축
