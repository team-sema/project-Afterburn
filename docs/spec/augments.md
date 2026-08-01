# 오그먼트

## Resource 모델

| 타입 | 필드 |
|------|------|
| `PlayerAugment` | 공통 필드 + `augment_type`, 필수 `facility_id` |
| `EnemyAugment` | `augment_id`, `display_name`, `description`, `stat_modifiers[]`, `behavior_components[]` |
| `PlayerStatModifier.Stat` | `MOVE_SPEED`, `FIRE_RATE`, `WEAPON_DAMAGE` |
| `EnemyStatModifier.Stat` | `HEALTH`, `MOVE_SPEED`, `ACTION_RATE` |

## 현재 풀 (World 익스포트)

### 플레이어

플레이어 풀의 모든 카드는 `facility_id`가 지정된 장착 모듈이다. 스탯 모듈 3종, 무기 강화 모듈 2종, 시설 효과 모듈 6종을 사용한다.

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
- PLAYER는 모듈 설치·교체 또는 부위 슬롯 확장 중 하나를 선택하고, ENEMY는 기존 단일 선택 단계를 사용한다
- `choices_per_offer = 3` (풀 크기 ≥ 3 필요)
- 빈 슬롯이면 즉시 설치하고, 가득 찬 부위면 `AugmentModuleSwapOverlay`에서 교체할 모듈을 고른다
- PLAYER 카드 포커스·호버는 `ShipPanel`의 대상 부위를 하이라이트한다
- PLAYER 오퍼 종료 시 함선 기준 `player_resume_clear_radius`(기본 36) 안 `enemy_projectiles` 제거 + resume burst VFX

### UI

- `AugmentSelectionOverlay` — 상단 카드 3개 + 하단 함선 부위 UI, 선택 일시중단·복귀 지원
- `AugmentModuleSwapOverlay` — 가득 찬 부위에서 교체 대상 선택·취소
- `AugmentBreakpointIntro` — AnimationPlayer `"reveal"`
- `ProgressionHud` — 플레이어 XP·다음 적 증강 타이머 · 준비 시 `[C]` 힌트
- `PauseOverlay` (`world_shell`) — ESC 수동 일시정지 (설정 메뉴는 미구현)

## 레지스트리

`PlayerAugmentRegistry`는 부위별 슬롯 용량과 `PlayerAugmentModuleState`를 함께 보유한다.

- 각 부위 슬롯 용량 1로 시작, `expand_slots`로 최대 3
- `install_augment`는 빈 슬롯에 설치하거나 지정 인덱스를 교체
- `get_active_augments` · `get_stack_count` · `get_effect_total` · `clear_augments`
- 시그널: `augments_changed`, `facility_slots_changed`

`EnemyAugmentRegistry`는 기존 누적 증강 API를 유지한다.

> 새 World 인스턴스는 모든 플레이어 함선 부위가 빈 슬롯 1개인 상태로 시작한다.

## EnemyFireVolumeBoostComponent

- 베이스 `EnemyShootComponent`의 `shot_count`에 `extra_shots` 가산(기본 +2)
- `spread_degrees`를 최소 `min_spread_degrees`(기본 18°)로 보장
- ACTION_RATE와 함께 위기 오퍼의 “더 많은 탄환” 축
