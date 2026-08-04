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

- 총 **25종**: 스탯 3 + 시설 효과 6 + 무기 획득 7 + 무기 레벨 7 + 무기 특성 2
- 카드 표시는 `get_offer_title` / `get_offer_description`으로 신규·레벨·특성을 구분
- 가중치: `offer_weight`(기본 1.0). 범주별 확정 %는 데이터에서만 조정
- 무기 전용 Kind는 **함선 시설 슬롯을 소모하지 않음**
- **리롤:** `max_reroll_count`(임시 기본 2), 런 `remaining_reroll_count`. 선택 전만. [R]/버튼. 직전 세트와 완전 동일하면 1회 재추첨

#### 스탯 모듈 3종

| ID | 표시명 | 대상 시설 | 효과 |
|----|--------|-----------|------|
| `player_move_speed_boost_1_2` | 과충전 추진기 | 엔진 | 이동속도 ×1.2 |
| `player_fire_rate_boost_1_2` | 가속 캐패시터 | 무기실 | 공격속도 ×1.2 |
| `player_weapon_damage_boost_1_2` | 과충전 탄두 | 무기실 | 장착한 모든 무기 피해 ×1.2 |

#### 시설 효과 모듈 6종

| ID | 표시명 | 대상 시설 | 1개 설치 효과 |
|----|--------|-----------|---------------|
| `facility_weapon_room` | 집속 조준기 | 무기실 | 장착 무기 공통 공격력 ×1.15 |
| `facility_hangar` | 격납고 확장 | 격납고 | 효과 미정 (현재 0) |
| `facility_engine` | 추력 편향기 | 엔진 | 이동속도 ×1.1 |
| `facility_hull` | 반응 장갑 | 선체 | 최대 선체 +1 |
| `facility_radar` | 광역 탐지기 | 레이더 | 픽업 수집 반경 ×1.15 |
| `facility_shield` | 실드 축전기 | 실드 | 최대 실드 +1 |

#### 무기 획득·레벨 7종씩

| 무기 ID | 표시명 | 획득 카드 ID | 레벨 카드 ID |
|---------|--------|--------------|--------------|
| `main_blaster` | 블래스터 | `acquire_main_blaster` | `level_main_blaster` |
| `main_laser` | 레이저 | `acquire_main_laser` | `level_main_laser` |
| `main_shotgun` | 샷건 | `acquire_main_shotgun` | `level_main_shotgun` |
| `aux_test_cannon` | 보조 캐넌 | `acquire_aux_test_cannon` | `level_aux_test_cannon` |
| `plasma_bomb` | 플라즈마 폭탄 | `acquire_plasma_bomb` | `level_plasma_bomb` |
| `aux_homing_missile` | 유도탄 | `acquire_aux_homing_missile` | `level_aux_homing_missile` |
| `aux_orbital_barrier` | 궤도 방벽 | `acquire_aux_orbital_barrier` | `level_aux_orbital_barrier` |

- 획득 카드는 Lv.1 신규 장착, 레벨 카드는 해당 무기가 장착 중일 때만 등장하며 최대 Lv.3
- 각 카드의 현재 `offer_weight`는 1.0

#### 무기 특성 2종

| 카드 ID | 표시명 | 대상 무기 | trait ID | 현재 상태 |
|---------|--------|-----------|----------|-----------|
| `trait_blaster_pierce` | 블래스터 관통 | 블래스터 | `blaster_pierce` | 관통 특성 스캐폴드 |
| `trait_laser_fork` | 레이저 분기 | 레이저 | `laser_fork` | 분기 특성 스캐폴드 |

### 적

| ID | 표시명 | 효과 |
|----|--------|------|
| `enemy_health_boost_1_2` | 적 증원 | 이후 스폰 적 HEALTH ×1.2 |
| `enemy_move_speed_boost_1_2` | 가속 적대 | 이후 스폰 적 MOVE_SPEED ×1.2 |
| `enemy_fire_volume_boost` | 포화 사격 | ACTION_RATE ×1.25 + 추가 탄 2발 + 최소 스프레드 18° |

`gameplay.tscn`의 적 증강 풀에는 위 **3종만** 등록되어 있다.

### 풀 미등록 리소스

| ID | 표시명 | 상태 |
|----|--------|------|
| `enemy_counter_shot_on_hit` | 보복 프로토콜 | 리소스는 존재하지만 Gameplay 적 증강 풀에는 미등록 |

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
