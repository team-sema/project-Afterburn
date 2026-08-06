# 플레이어

## Ship (`player_ship/ship.gd`)

- 그룹: `"player"`
- `PlayerAugmentRegistry` 주입 → `PlayerAugmentApplier.initialize` / `ShipFacilityApplier.initialize`
- `WeaponMount` 아래 모든 `WeaponSystem` 수집
- 무기 `fired` → `ScaleComponent.tween_scale()`

### 주요 자식

Move / MoveInput / PositionClamp / WeaponMount(Blaster·Laser·Shotgun 등) / PlayerAugmentApplier / **ShipFacilityApplier** / **ShipCombatBuffController** / **EngineBoostComponent** / Scale / Stats(**기본 HP 1**) / Shield(**시작 최대 1**) / ExperienceCollector / PlayerHitPoint / Hurt / ExplosionSpawner / Destroyed

## ExperienceCollector

- 기본 수집 반경 **36px** (`collection_radius`) · 레이더 시설 배율이 곱해짐
- XP 오브가 범위에 들어오면 바깥으로 짧게 튕긴 뒤 플레이어에게 가속
- 오브 비주얼: 황금 글로우 사각 보급상자 (`pickups/experience_orb.tscn`, `assets/svg/supply_crate.svg`)
- Collector 중심 근처에서 XP를 지급하며 PlayerHitPoint와 독립

## PlayerHitPoint

- 코어 히트 반경(기본 **3px**)
- Hurtbox CollisionShape + 비주얼 스케일
- 플레이어 Hurtbox 위치 (기본 **layer 1** `player_hurtbox`)

# 무기 (통합 장착 베이)

- `PlayerWeaponLoadout`: `max_equipped_weapon_count`(기본 3)개의 장착 베이. 주/보조·메인/예비 구분 없음
- 시작: 블래스터가 베이 0에 모듈 없이 장착
- 장착된 무기는 각자 쿨다운으로 **동시에** 작동. 탄약·소진 삭제 없음
- 성장은 `weapon_id`별 중앙 상태(`WeaponProgressState`: `trait_ranks`). **장착 중인 무기의 모듈 레벨만** 보유
- **무기 획득·모듈 강화**는 레벨업 **증강 선택**으로만 처리 (필드 무기 드롭 없음)
- 빈 베이면 신규 자동 장착. 만석이면 증강 화면에서 교체 → **피교체 무기 모듈 레벨 완전 삭제**
- 같은 무기를 다시 얻으면 모듈 없음으로 시작 (교체로 뺀 모듈은 보존하지 않음)
- 무기실: 집속 조준기(공통 피해) · 사격 통제 장치(공통 공속) · 대형 표적 해석기(보스 피해)
- HUD: `WeaponLoadoutHud` — 동일 크기 장착 베이 헥스 가로 행. 템플릿(`%BaySlotTemplate` · `%ModuleHexTemplate` · `%SelectedWeaponHex`) 복제. 호버/클릭 포커스 → 하단 `선택된 무기` | `장착된 모듈` + 설명(전투 수치는 인게임 비표시). 설명은 고정 2줄·말줄임이며 우측 레일의 최소 크기를 늘리지 않는다
- 증강 리롤: `AugmentOfferController.max_reroll_count`(임시 기본 2) · 런당 `remaining_reroll_count`

## 현재 무기 목록 (`gameplay.tscn` 획득 풀)

| id | 표시명 | 현재 역할 |
|----|--------|-----------|
| `main_blaster` | 블래스터 | 좌우 교대 발사형. 시작 시 베이 0에 장착 |
| `main_laser` | 레이저 | 연속 빔형 |
| `main_shotgun` | 샷건 | 부채꼴 다중 펠릿 근거리 화력 |
| `aux_test_cannon` | 보조 캐넌 | 좌우 목표점을 지연 추종하는 **옵션 드론 2기**가 전방 동시 발사. 플레이어 중심에서 멀수록 소폭 가속, 편대 증설 프레임으로 4기 |
| `plasma_bomb` | 플라즈마 폭탄 | 지연 폭발·범위 피해 · 방사형 클러스터 자탄 · 잔류장 |
| `aux_homing_missile` | 유도탄 | 가까운 적을 추적 |
| `aux_orbital_barrier` | 궤도 방벽 | 주변을 돌며 탄막 소멸 + 적 접촉 피해(**적당 1회**, 일부 trait는 재타격 쿨). 기본 길이 `segment_arc_length≈11.33`(구 34의 1/3). HP 없음 |

### 기본 전투 수치 (WeaponSystem 씬 · 모듈/시설 배율 1.0)

정본은 각 `player_ship/weapons/*_weapon_system.tscn` 익스포트. 무기 모듈·시설 배율이 적용되면 실효값은 달라진다. **인게임 STATUS에는 표시하지 않는다.**

| 무기 | 핵심 수치 |
|------|-----------|
| 블래스터 | 피해 10 · 간격 0.15초 · 탄속 200 |
| 레이저 | 틱피해 3 · 틱 0.1초 · `laser_pulse` OFF 시 빔 알파 페이드(~0.12초) |
| 샷건 | 펠릿 피해 4 × 5발 · 간격 0.42초 · 확산 36° · 펠릿 속 200 |
| 보조 캐넌 | 드론 2기 · 추종 100px/s + 본체 중심 거리×15%(최대 +50) · 드론당 피해 9 · 간격 0.8초 · 탄속 190 · 전방 고정 사격 |
| 플라즈마 폭탄 | 피해 32 · 간격 1.2초 · 탄속 66 · 신관 1.0초 · 반경 32 |
| 유도탄 | 피해 14 · 간격 1.1초 · 탄속 150 · 선회 5.5 · 재탐색 0.15초 |
| 궤도 방벽 | 접촉피해 6(**같은 적에게 1회만**, trait에 따라 재타격 쿨) · 반경 22 · 회전 2.8 · **길이 ≈11.33** |

- 위 7종 모두 `WEAPON_ACQUIRE` 카드와 전용 `WEAPON_TRAIT` 모듈 4종이 Gameplay 플레이어 증강 풀에 등록되어 있다
- 무기 정의 파일이 존재하더라도 `gameplay.tscn`의 획득 풀에 없으면 현재 플레이 가능한 무기 목록에 포함하지 않는다

### 조작 요약 (전투 중)

| 입력 | 동작 |
|------|------|
| WASD / 화살 | 이동 |
| 발사 | 장착 무기 자동 사격 |
| **C** | XP 준비 시 플레이어 오그먼트 오픈 |
| **Shift** (`engine_boost`) | 비상 부스터 모듈 장착 시에만 · 0.8초 ×2.5 이동 · CD 7초 |
| **ESC** | 수동 일시정지 토글 (오퍼 pause와 분리) |

## PlayerAugmentApplier

`PlayerAugmentRegistry.augments_changed` / `refresh()` 시 재계산한다.

- 이동속도 = 씬 기본 × **엔진 시설 효과** (`ShipFacilityApplier` → `facility_move_speed_multiplier`)
- 범용 공격 속도·피해는 무기실 `WEAPON_FIRE_RATE_MULT` / `WEAPON_DAMAGE_MULT` 시설 모듈로 갱신
- `WEAPON_TRAIT` → `PlayerWeaponLoadout.add_or_upgrade_weapon_trait`; 각 `WeaponSystem`이 현재 Lv.I~III의 `get_trait_param`을 적용
- 무기 자체 레벨은 없고, 무기 모듈만 증강 선택으로 성장 (필드 픽업 없음)

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).

## 함선 부위와 모듈 슬롯 (`PlayerAugmentRegistry` / `ShipFacilityApplier`)

**부위 슬롯에 들어가는 플레이어 모듈은 `FACILITY_EFFECT`만이다.** 효과는 카드의 `FacilityModuleEffect`로 정의되며, 동일 Kind는 배율 곱·가산 합으로 중첩한다.
무기 획득·전용 모듈 증강은 시설 슬롯을 소모하지 않는다. 모듈 목록·수치는 [`augments.md`](augments.md) 「시설 효과 모듈 13종」이 정본.

| id | 이름(표시) | 담당 모듈 예 |
|----|------------|--------------|
| `weapon_room` | 무기실 | 집속 조준기 · 사격 통제 장치 · 대형 표적 해석기 |
| `hangar` | **동력로** | 과충전 반응로 · 비상 출력 장치 |
| `engine` | 엔진 | 추력 편향기 · 비상 부스터(Shift) |
| `hull` | 선체 | 반응 장갑 · 충격 분산 골격 |
| `radar` | 레이더 | 광역 탐지기 · 전투 데이터 분석기 |
| `shield` | 실드 | 실드 축전기 · 급속 재충전기 |

- 모든 부위는 빈 슬롯 1개로 시작하며, 플레이어 오퍼 하나를 소비해 최대 3개까지 확장할 수 있다
- 증강 선택 시 빈 슬롯에 설치한다. 슬롯이 가득 찼으면 교체 창에서 기존 모듈 하나를 선택하며, 취소하면 오퍼로 돌아간다
- 동일 모듈의 중복 설치와 효과 중첩을 허용한다 (Kind별 곱/합)
- 선체: `ShipFacilityApplier`가 최대 선체 = `기본 + MAX_HULL_ADD`(최소 1). 최대치 증가분만큼 현재 선체도 함께 증가
- 레이더: 수집 반경 = 기본 36 × `PICKUP_RANGE_MULT`. XP 획득 = 드롭량 × `XP_GAIN_MULT`
- 실드: 아래 「선체 · 실드」
- 전투 중 `ShipPanel`은 읽기 전용. 플레이어 증강 오퍼 안의 `ShipPanel`만 확장 부위 선택 가능
- 슬롯은 둥근 사각 프레임 + 모듈 `icon`

## 플레이어 증강 오퍼

- 화면 상단에 증강 3개, 구분선 아래에 현재 카드 Kind의 적용 대상 UI를 표시한다
- `STAT_MULTIPLIER`는 플레이어 오퍼 풀에 없다. `FACILITY_EFFECT` 카드 포커스·호버만 대상 `facility_id` 부위를 하이라이트한다. 무기 Kind 카드는 시설 하이라이트를 강제하지 않는다
- 무기 Kind 카드 포커스 시 함선 부위 UI 대신 현재 병기 배치를 표시한다. 신규 획득은 빈 슬롯/교체 안내, 모듈은 대상 병기와 현재→다음 레벨을 강조한다
- 카드 대신 확장 가능한 함선 부위를 선택하면 해당 부위의 빈 슬롯을 1개 늘리고 오퍼를 종료한다
- 확장 부위에 키보드 포커스 또는 마우스 호버가 들어오면 추가될 다음 슬롯이 점멸한다
- 카드 3개와 확장 가능한 부위 6개는 방향키·Tab으로 이동하고 `ui_accept`로 선택할 수 있다
- 시설 모듈 리소스만 유효한 `facility_id`를 가지며 슬롯에 설치된다. 무기 Kind는 시설 슬롯에 설치되지 않는다
- 적 증강 오퍼는 함선 UI 없이 기존 3지선다를 유지한다

## 선체 · 실드

- `ShieldComponent`(함선 자식): `get_current_shield()` / `get_max_shield()` / `get_charge_progress()` / `add_shield(amount)`(최대치 +, 현재도 같은 양 상승) / `restore_shield(amount)`(현재만 충전, 최대 이내) / `notify_hit()` / `absorb_damage(damage) -> int`(실드에 먼저 적용 후 **선체로 넘길 남은 피해** 반환), 시그널 `shield_changed(current, max)` · `shield_absorbed(absorbed)` · `charge_changed(progress)`
- **플레이어 피격 피해는 이벤트당 항상 1.** `HurtComponent`가 `player` 그룹이면 hitbox.damage와 무관하게 1로 적용한다. (폭탄 자폭 등 소스 수치도 1로 맞춤)
- **실드 버퍼**: `HurtComponent`가 피격마다 `notify_hit()` 후 `absorb_damage()`를 부른다. 실드가 있는 만큼만 흡수하고 초과분은 선체 HP에서 차감한다. 피해가 항상 1이므로 실드 1이면 그 한 방은 실드만 깎인다.
- **실드 재생**: 현재 < 최대면 충전 게이지 진행(`regen_charge_duration` 기본 30초 · 급속 재충전기로 속도 ×2). 완료 시 +1. 피격 시 게이지 리셋 후 즉시 재개. 최대면 게이지 0·숨김
- 모든 피격 후 기본 0.6초 무적 및 기체 반투명 표시(추가 피격으로 타이머 연장 안 함). **충격 분산 골격** 장착 시 선체 피격 무적시간 +1.0초(총 1.6초)
- 한 프레임에 여러 히트박스가 겹치면 각각 별개 이벤트(각 1 피해)
- HUD: 좌측 `ShipStatusHud` — `HULL` · `SHIELD` · 실드 바 아래 `ShieldChargeBar`(미만일 때만). 함선 파괴 시 `—`
