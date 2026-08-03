# 오그먼트

## Resource 모델

| 타입 | 필드 |
|------|------|
| `PlayerAugment` | 공통 필드 + `augment_type`, `offer_weight`, 무기 필드(`weapon_definition`, `starting_weapon_level`, `trait_*`) |
| `EnemyAugment` | `augment_id`, `display_name`, `description`, `stat_modifiers[]`, `behavior_components[]` |
| `PlayerStatModifier.Stat` | `MOVE_SPEED`, `FIRE_RATE`, `WEAPON_DAMAGE` |
| `EnemyStatModifier.Stat` | `HEALTH`, `MOVE_SPEED`, `ACTION_RATE` |
| `PlayerAugmentKind` | `STAT_MULTIPLIER`, `WEAPON_ACQUIRE`, `WEAPON_LEVEL`, `WEAPON_TRAIT`, `FACILITY_EFFECT` |

## 현재 풀 (Gameplay 익스포트)

### 플레이어

- 스탯 모듈 3종 (시설 슬롯 소모)
- 시설 효과 모듈 6종
- 무기 획득(`WEAPON_ACQUIRE`) 7종 · 레벨(`WEAPON_LEVEL`) 7종 · 특성 스캐폴드 2종
- 카드 표시는 `get_offer_title` / `get_offer_description`으로 신규·레벨·특성을 구분 (기록 복원 없음)
- 가중치: `offer_weight`(기본 1.0). 범주별 확정 %는 데이터에서만 조정
- 무기 전용 Kind는 **함선 시설 슬롯을 소모하지 않음**
- **리롤:** `max_reroll_count`(임시 기본 2), 런 `remaining_reroll_count`. 선택 전만. [R]/버튼. 직전 세트와 완전 동일하면 1회 재추첨

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

### AugmentOfferController

- PLAYER 선택지: 풀 필터 + `offer_weight` 비가중 추출
- `WEAPON_ACQUIRE` 만석 시 `WeaponSlotSelectionOverlay`로 교체 베이 선택(취소 시 카드 선택으로 복귀). **확정 시 피교체 무기 성장 삭제**
- `WEAPON_LEVEL` / `WEAPON_TRAIT` → 장착 중 무기만 (`PlayerWeaponLoadout`)
- PLAYER 리롤 → 후보 전체 재생성 (효과 미적용)

### UI

- `AugmentSelectionOverlay` — 상단 카드 3개 + 하단 함선 부위 UI
- `WeaponSlotSelectionOverlay` — 만석 시 무기 베이 교체
- `AugmentModuleSwapOverlay` — 시설 모듈 교체
- `ProgressionHud` — XP · `[C]` 힌트

## 필드 드롭

- 무기 필드 드롭 **비활성** (`WeaponDropComponent.enabled = false`)
- XP: `ExperienceDropComponent.drop_chance`(기본/enemy 0.62, 구 0.5). `experience_amount`는 적별 유지

## 레지스트리

`PlayerAugmentRegistry`는 부위별 슬롯 용량과 `PlayerAugmentModuleState`를 함께 보유한다. 무기 전용 증강은 여기 설치하지 않는다.
