# 오그먼트

## Resource 모델

| 타입 | 필드 |
|------|------|
| `PlayerAugment` | 공통 필드 + `augment_type`, `offer_weight`, `facility_id`, `facility_module_effect`, 무기 필드(`weapon_definition`, `starting_weapon_level`, `trait_*`) |
| `FacilityModuleEffect` | `kind` + `primary` / `secondary` / `tertiary` (시설 모듈 효과 페이로드) |
| `WeaponTraitDefinition` | `trait_id`, `target_weapon_id`, `params` Dictionary (무기별 전투 튜닝) |
| `EnemyAugment` | 공통 필드 + `icon`, `max_stacks`, `stat_modifiers[]`, `behavior_components[]`, `target_spawn_id`, `additional_spawn_count` |
| `PlayerStatModifier.Stat` | `MOVE_SPEED`, `FIRE_RATE`, `WEAPON_DAMAGE` (enum 잔여 · **플레이어 오퍼 풀 미사용**) |
| `EnemyStatModifier.Stat` | `HEALTH`, `MOVE_SPEED`, `ACTION_RATE`, `ARMING_RATE` |
| `PlayerAugmentKind` | `FACILITY_EFFECT`, `WEAPON_ACQUIRE`, `WEAPON_LEVEL`, `WEAPON_TRAIT` (+ enum에 `STAT_MULTIPLIER` 잔여·풀 미사용) |

## 현재 풀 (Gameplay 익스포트)

### 플레이어

- 총 **54종**: 시설 효과 **12** + 무기 획득 7 + 무기 레벨 7 + 무기 특성 **28**
- **함선 부위 슬롯 모듈은 `FACILITY_EFFECT`만.** 각 카드의 `facility_module_effect`(`FacilityModuleEffect`)가 효과를 정의한다. 동일 Kind는 primary **곱**(배율) / **합**(가산).
- 카드 표시는 `get_offer_title` / `get_offer_description`으로 신규·레벨·특성을 구분
- 가중치: `offer_weight`(기본 1.0)
- 무기 전용 Kind는 **함선 시설 슬롯을 소모하지 않음**
- **리롤:** `max_reroll_count`(임시 기본 2), 런 `remaining_reroll_count`. 선택 전만. [R]/버튼

#### 시설 효과 모듈 12종

`facility_id` `hangar`는 UI 표시명 **동력로**. 슬롯 키는 호환을 위해 `hangar` 유지.

| ID | 표시명 | 부위 | Kind · 수치 |
|----|--------|------|-------------|
| `facility_weapon_room` | 집속 조준기 | 무기실 | `WEAPON_DAMAGE_MULT` ×1.15 |
| `facility_weapon_room_boss` | 대형 표적 해석기 | 무기실 | `BOSS_DAMAGE_MULT` ×1.3 (`Enemy.is_boss`) |
| `facility_hangar` | 과충전 반응로 | 동력로 | `PERIODIC_DAMAGE_BUFF` ×1.4 · 5초 · 주기 20초 |
| `facility_reactor_emergency` | 비상 출력 장치 | 동력로 | `HULL_HIT_DAMAGE_BUFF` ×1.3 · 5초 · CD 15초 (**선체 피격만**) |
| `facility_engine` | 추력 편향기 | 엔진 | `MOVE_SPEED_MULT` ×1.25 |
| `facility_engine_boost` | 비상 부스터 | 엔진 | `ENGINE_BOOST` ×2.5 · 0.8초 · CD 7초 · 입력 `engine_boost`(**Shift**) |
| `facility_hull` | 반응 장갑 | 선체 | `MAX_HULL_ADD` +1 |
| `facility_hull_iframe` | 충격 분산 골격 | 선체 | 선체 피격 무적시간 +1.0초 |
| `facility_radar` | 광역 탐지기 | 레이더 | `PICKUP_RANGE_MULT` ×1.5 |
| `facility_radar_xp` | 전투 데이터 분석기 | 레이더 | `XP_GAIN_MULT` ×1.5 |
| `facility_shield` | 실드 축전기 | 실드 | `MAX_SHIELD_ADD` +1 |
| `facility_shield_charge` | 급속 재충전기 | 실드 | `SHIELD_CHARGE_SPEED_MULT` ×2 (게이지 속도만) |

적용: `ShipFacilityApplier` · `ShipCombatBuffController` · `EngineBoostComponent` · `HurtComponent`(iframe). 상세 설계: [`docs/design/systems/facility-weapon-modules.md`](../design/systems/facility-weapon-modules.md).

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
- 레벨 배율: Lv.2 피해 ×1.2 · Lv.3 피해 ×1.2 + 공속 ×1.2

#### 무기 특성 28종 (전투 적용됨)

`WeaponTraitDefinition.params` + 각 `*WeaponSystem`. rank≥1이면 활성(랭크 추가 스케일 없음). 카드 ID = `trait_<trait_id>`.

| 무기 | trait_id | 표시명(요지) |
|------|----------|--------------|
| 블래스터 | `blaster_rapid_loader` | 고속 급탄기 — 간격 ×0.72 · 피해 ×0.95 |
| | `blaster_sync_trigger` | 동기화 방아쇠 — 좌우 동시 · 피해 ×0.85 · 간격 ×1.15 |
| | `blaster_accel_ap` | 가속 철갑탄 — 관통+1 · 탄속 ×1.3 · 관통 후 피해 ×0.7 |
| | `blaster_ricochet` | 도탄 탄자 — 최대 2회 도탄(70%/40%) |
| 레이저 | `laser_wide_lens` | 광폭 집광 — 폭 ×1.8 · 피해 ×0.9 |
| | `laser_heat_stack` | 열 누적 — 0.5초마다 +15% · 최대 +90% |
| | `laser_refract` | 굴절 중계 — 보조 빔 피해 55% |
| | `laser_pulse` | 펄스 발진 — 0.7초 온/0.35초 오프 · 온 시 피해 ×2 · **오프 전환 시 빔 페이드아웃(~0.12초)** |
| 샷건 | `shotgun_expanded_shell` | 확장형 탄피 — 펠릿+4 · 피해 ×0.85 |
| | `shotgun_choke` | 초크 튜브 — 산탄각 ×0.5 · 사거리 ×1.4 · 탄속 ×1.2 |
| | `shotgun_cut_barrel` | 절단 총열 — 산탄각 ×1.5 · 근거리 피해 ×1.8 · 사거리 ×0.85 |
| | `shotgun_burst_device` | 연속 격발 — 3발마다 추가 사격(피해 ×0.9) |
| 보조 캐넌 | `aux_heavy_barrel` | 대구경 포신 — 피해 ×1.8 · 크기 ×1.3 · 간격 ×1.2 |
| | `aux_auto_loader` | 자동 장전기 — 간격 ×0.65 · 피해 ×0.9 |
| | `aux_he_shell` | 고폭탄 — 직격 ×0.95 + AOE 80% |
| | `aux_hv_ap` | 초고속 철갑 — 피해 ×1.1 · 탄속 ×1.6 · 관통+3 · 관통 후 ×0.9 |
| 플라즈마 | `plasma_expand` | 팽창형 — 반경 ×1.6 · 피해 ×1.1 |
| | `plasma_cluster` | 집속 폭발 — 피해 ×0.9 + 방사형 소형 3발(각 40%) |
| | `plasma_field` | 잔류 플라즈마장 — 피해 ×0.95 + 반투명 3초 지대 |
| | `plasma_gravity` | 중력 기폭 — 넓은 범위 강한 흡인 · 피해 ×1.35 · 반경 ×0.9 |
| 유도탄 | `missile_multi_rack` | 다중 발사대 — +1발 · 피해 ×0.9 |
| | `missile_high_mobility` | 고기동 — 탄속 ×2 · 발사 간격 ×0.7 (**선회 변경 없음**) |
| | `missile_proximity` | 근접 신관 — 직격 ×0.95 + AOE 80% |
| | `missile_terminal` | 종말 가속 — 비행시간 피해 +20%~+100% (**선회 변경 없음**) |
| 궤도 방벽 | `barrier_multi` | 다중 궤도 — 방벽+1 · 피해 ×0.9 |
| | `barrier_fast_orbit` | 고속 공전 — 공전 ×1.5 · 재타격 쿨 ×0.7 · 피해 ×0.95 |
| | `barrier_expand_axis` | 확장형 궤도축 — 반경 ×1.45 · 크기 ×1.35 · 공전 ×0.9 |
| | `barrier_repulse` | 반발 역장 — 밀침 + 충격 피해 40% · 재타격 쿨 ×0.85 |

플라즈마 본체·자탄·잔류장은 발사 시점의 일반/보스 피해 배율을 값으로 보존한다. 발사 후 플라즈마 무기를 교체하거나 해제해도 이미 생성된 투사체와 지대는 해당 배율로 끝까지 동작한다.

### 적

| ID | 표시명 | 효과 |
|----|--------|------|
| `enemy_health_boost_1_2` | 적 증원 | 이후 스폰 적 HEALTH ×1.2 |
| `enemy_move_speed_boost_1_2` | 가속 적대 | 이후 스폰 적 MOVE_SPEED ×1.2 |
| `enemy_fire_volume_boost` | 포화 사격 | ACTION_RATE ×1.25 + 추가 탄 2발 + 최소 스프레드 18° |
| `enemy_near_death_experience` | 임사 체험 | 치명 피해 시 HP 1 · 1초 무적 임사 상태 후 사망 · one-time |
| `enemy_drone_formation_reinforcement` | 드론 증원 편대 | Drone 편대 스폰 +1 · one-time · Drone SVG 프리뷰 |
| `enemy_bomb_fast_fuse` | 고속 기폭 장치 | Bomb 무장 시간 ÷1.5 · one-time · Bomb SVG 프리뷰 |

`gameplay.tscn`의 적 증강 풀에는 위 **6종**이 등록되어 있다. `max_stacks`는 `0`이면 무제한, `1`이면 one-time이며 한도에 도달한 증강은 이후 후보에서 제외된다.

`target_spawn_id`는 증강 효과를 특정 `EnemySpawnSet`에 한정한다. `additional_spawn_count`는 스폰 수 보너스를 전달하며 현재 `drone_formation` 패턴이 이를 편대원 수에 반영한다. 대상이 지정된 스탯 modifier도 같은 `spawn_id`의 적에만 적용된다.

### 풀 미등록 리소스

| ID | 표시명 | 상태 |
|----|--------|------|
| `enemy_counter_shot_on_hit` | 보복 프로토콜 | 리소스는 존재하지만 Gameplay 적 증강 풀에는 미등록 |

## 트리거 · 컨트롤러

### AugmentProgressionController

- 플레이어: 경험치 오브 획득 → 요구량 충족 시 HUD에 `AUGMENT READY [C]` (자동 오퍼 없음)
- 입력 `open_augment_offer`(**C**): XP ≥ 요구량일 때만 PLAYER 오퍼 오픈 · 성공 시 XP 차감·레벨+1
- XP 획득량에 레이더 `XP_GAIN_MULT` 배율 적용 (`experience_gain_multiplier`)
- 첫 요구 경험치 `5`, 레벨마다 요구량 `+3`
- 적: 플레이 시간 `60초`마다 ENEMY 오퍼를 큐에 추가

### AugmentOfferController

- PLAYER 선택지: 풀 필터 + `offer_weight` 비가중 추출
- `WEAPON_ACQUIRE` 만석 시 `WeaponSlotSelectionOverlay`로 교체 베이 선택(취소 시 카드 선택으로 복귀). **확정 시 피교체 무기 성장 삭제**
- `WEAPON_LEVEL` / `WEAPON_TRAIT` → 장착 중 무기만 (`PlayerWeaponLoadout`)
- PLAYER 리롤 → 후보 전체 재생성 (효과 미적용)
- ENEMY 선택지: `max_stacks` 한도에 도달한 증강 제외

### UI

- `AugmentSelectionOverlay` — 상단 카드 3개 + 선택 Kind에 따라 전환되는 하단 적용 대상 UI
  - `FACILITY_EFFECT` 포커스: 함선 부위 UI와 대상 `facility_id` 하이라이트
  - `WEAPON_ACQUIRE` 포커스: 현재 병기 배치와 신규 배치/교체 안내
  - `WEAPON_LEVEL` / `WEAPON_TRAIT` 포커스: 대상 병기 슬롯·레벨·현재/추가 증강 미리보기
  - 적 그룹 증강: `EnemyAugment.icon`에 지정된 적 SVG를 카드 아이콘으로 표시
- `WeaponSlotSelectionOverlay` — 만석 시 무기 베이 교체
- `AugmentModuleSwapOverlay` — 시설 모듈 교체
- `ProgressionHud` — XP · `[C]` 힌트

### 통합 증강 테스트 랩

- `weapon_test/weapon_test_lab.tscn`에서 `C`는 PLAYER, `V`는 ENEMY 강화 이벤트를 모의 발생시킨다.
- `C` 목록은 시설 증강 12종만 표시한다. 무기 획득·레벨·특성은 기존 랩 오른쪽 무기 UI가 담당한다.
- `V` 목록은 실제 런의 3장 무작위 오퍼 대신 적 증강 리소스 전체를 스크롤 목록으로 연다.
- 목록 행은 아이콘 원본 크기에 영향받지 않는 고정 높이 텍스트 카드로 표시한다.
- PLAYER 시설 12종과 ENEMY 7종(게임플레이 풀 미등록 `enemy_counter_shot_on_hit` 포함)을 직접 선택해 랩의 레지스트리에 적용한다.
- 시설 슬롯 확장·교체는 테스트 편의를 위해 랩이 자동 처리한다. Gameplay의 XP/60초 트리거와 후보 필터는 바꾸지 않는다.

## 필드 드롭

- 무기 필드 드롭 **비활성** (`WeaponDropComponent.enabled = false`)
- XP: `ExperienceDropComponent.drop_chance`(기본/enemy 0.62). `experience_amount`는 적별 유지

## 레지스트리

`PlayerAugmentRegistry`는 부위별 슬롯 용량과 `PlayerAugmentModuleState`를 함께 보유한다. 슬롯에는 `FACILITY_EFFECT`만 설치한다. `get_module_effect_product` / `get_module_effect_sum`으로 Kind별 합산.
