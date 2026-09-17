# 오그먼트

## 기획 의도

XP를 모은 뒤 플레이어가 선택 시점을 정하며, 무기·모듈·시설로 빌드를 바꾼다. 적 증강은 다음 구간의 압력을 높인다.

카드 **목록·아이콘·수치** 정본:

- 플레이어 시설 → [함선 모듈](ship-modules/index.md)
- 무기 획득·특성 → [무기 모듈](weapon-modules/index.md)
- 적 증강 → 아래 「적 풀」

## Resource 모델

플레이어 증강이 비행 중 적탄의 궤도에 개입하는 공통 접점은 [전투 — 외부 궤도 개입 설계](combat.md#외부-궤도-개입-설계--후속-구현)를 따른다. 증강은 효과의 대상 선택·범위·수명과 탄별 핸들을 소유하고, 전투 런타임은 방향 오프셋/속도 배율 합성과 과거 보존·미래 예측 갱신을 소유한다. 이번 작업은 접점 설계이며 새 증강 카드·밸런스 수치·실제 적탄 적용은 추가하지 않는다.

| 타입 | 요지 |
|------|------|
| `PlayerAugment` | `tier` · `augment_type` · `offer_weight` · 시설/무기 필드 |
| `FacilityModuleEffect` | Kind + primary/secondary/tertiary |
| `WeaponTraitDefinition` | `max_rank` 3 · `params` / `rank_overrides` |
| `EnemyAugment` | `icon` · `max_stacks` · modifiers · spawn 보너스 |
| `PlayerAugmentKind` | `FACILITY_EFFECT` · `WEAPON_ACQUIRE` · `WEAPON_TRAIT` |

## 풀

`AugmentPoolLoader`가 폴더 스캔 (`auto_load_offer_pools`).

| 대상 | 경로 | 포함 |
|------|------|------|
| 플레이어 | `resources/player_augments/` | Kind 3종 · `offer_weight > 0` → **48종** (시설 13 + 획득 7 + 특성 28) |
| 적 | `resources/enemy_augments/` | `include_in_offer_pool == true` → **6종** |

- 티어 필드(`SILVER`/`GOLD`/`PRISMATIC`)는 카드 UI에만 반영 · 등장 확률 미분기
- 리롤: `max_reroll_count`(임시 2) · **포커스 카드 1장만** 교체
- 무기 Kind는 함선 범용 슬롯을 **쓰지 않음**

### 적 풀

| ID | 표시명 | 효과 | 아이콘 |
|----|--------|------|--------|
| `enemy_health_boost_1_2` | 적 증원 | HEALTH ×1.2 | — |
| `enemy_move_speed_boost_1_2` | 가속 적대 | MOVE_SPEED ×1.2 | — |
| `enemy_fire_volume_boost` | 포화 사격 | ACTION_RATE ×1.25 + 탄 2 · 스프레드 18° | — |
| `enemy_near_death_experience` | 임사 체험 | 치명 시 HP1 · 1초 무적 후 사망 · one-time | — |
| `enemy_drone_formation_reinforcement` | 드론 증원 편대 | Drone 편대 +1 · one-time | ![드론](enemies/sprites/enemy_drone.svg) |
| `enemy_bomb_fast_fuse` | 고속 기폭 장치 | Bomb 무장 ÷1.5 · one-time | ![폭탄](enemies/sprites/enemy_bomb.svg) |

미등록: `enemy_counter_shot_on_hit` (`include_in_offer_pool = false`, 랩만).

`max_stacks` 0=무제한 · 1=one-time. `target_spawn_id` / `additional_spawn_count`는 Encounter 한정 보너스.

## 트리거

### AugmentProgressionController

- 플레이어: XP ≥ 요구량 → HUD `AUGMENT READY [C]` · **C**로만 오픈 · 성공 시 XP 차감·레벨+1
- 첫 요구 5, 레벨마다 +3 · 레이더 `XP_GAIN_MULT` 적용
- 적: ~60초 → Threat 엘리트 → **처치 후** ENEMY 오퍼 · 선택 완료까지 타이머/일반 스폰 정지

### AugmentOfferController

- PLAYER 3장: `offer_weight` × 범주 배율 (획득 ×1.8 / 모듈 ×0.45 / 시설 ×1.0 · 베이 만석 시 획득·모듈 하향)
- `WEAPON_ACQUIRE` 만석 → 교체 UI · 피교체 무기 성장 삭제
- `WEAPON_TRAIT` → 장착 중 무기만 · Lv.III 제외

### UI 요약

- 중앙 플레이필드 3장 캐러셀 · 포커스 미리보기는 우측 STATUS
- 시설: 빈 범용 슬롯 아이콘 점멸 · 무기: 베이/모듈 칸 점멸
- 하단 `범용 슬롯 +1` 항상 표시(최대 15면 비활성) · `[R] 리롤`
- 랩: `weapon_test_lab` · C=시설 목록 · V=적 증강 전체

## 레지스트리 · 드롭

- `PlayerAugmentRegistry`: 범용 슬롯 배열 · 시설만 설치
- 무기 필드 드롭 비활성 · XP 드롭은 적별 `ExperienceDropComponent`

## 완료 조건·검증

- XP만으로 오퍼가 자동 열리지 않고 C로 연다.
- 풀·장착·Lv.III·리롤 규칙이 위와 같다.

검증 참고: `tests/augment_pool_data_driven_smoke_test.gd`.

## 변경 이력

- 2026-09-15: 카드 카탈로그를 함선/무기 모듈 문서로 분리하고 오그먼트는 풀·트리거·UI만 유지.
- 2026-09-13: 주제별 통합 기획서로 이전.
- 2026-09-06: `AugmentPoolLoader` 폴더 스캔.
