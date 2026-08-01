# 플레이어

## Ship (`player_ship/ship.gd`)

- 그룹: `"player"`
- `PlayerAugmentRegistry` 주입 → `PlayerAugmentApplier.initialize`
- `WeaponMount` 아래 모든 `WeaponSystem` 수집
- 무기 `fired` → `ScaleComponent.tween_scale()`

- `ShipFacilityRegistry` 주입 → `ShipFacilityApplier.initialize` (없으면 경고 후 시설 Lv.1 고정)

### 주요 자식

Move / MoveInput / PositionClamp / WeaponMount(Blaster·Laser·Shotgun 등) / PlayerAugmentApplier / **ShipFacilityApplier** / Scale / Stats(**기본 HP 1**) / ExperienceCollector / PlayerHitPoint / Hurt / ExplosionSpawner / Destroyed

## ExperienceCollector

- 기본 수집 반경 **36px** (`collection_radius`) · 레이더 시설 배율이 곱해짐
- XP 오브가 범위에 들어오면 바깥으로 짧게 튕긴 뒤 플레이어에게 가속
- 오브 비주얼: 황금 글로우 사각 보급상자 (`pickups/experience_orb.tscn`, `assets/svg/supply_crate.svg`)
- Collector 중심 근처에서 XP를 지급하며 PlayerHitPoint와 독립

## PlayerHitPoint

- 코어 히트 반경(기본 **3px**)
- Hurtbox CollisionShape + 비주얼 스케일
- 플레이어 Hurtbox 위치 (기본 **layer 1** `player_hurtbox`)

## 무기 (슬롯 무장)

- `PlayerWeaponLoadout`: 주무기 **메인(발사) + 예비** + 보조 최대 3
- 시작 주무기: 블래스터가 메인 슬롯 (무기 Lv.1), 예비 빈칸
- 주무기 후보: 블래스터 · 레이저 · **샷건**(부채꼴 5펠릿)
- **주무기 필드 픽업**: 무기 ID 레벨 상승·보존. 새 무기면 **예비 슬롯 교체**(확인 UI 없음). **X**로 미보유 주무기 픽업 차단 토글
- **Z**: 메인 ↔ 예비 스왑 (예비 비어 있으면 무시)
- **보조무기**: 소모품. 동일 픽업 = 사용량 리필, 소진 시 슬롯 제거. 무기 레벨은 재획득 후에도 보존
- **무기 강화**: 모든 주·보조무기는 무기 ID별 Lv.1~3 하나만 사용. 주무기 픽업 또는 주/보조 무기 강화 오그먼트로 상승
- 주무기 최종 배율 = 플레이어 공통 × **무기 레벨** × **무기실(시설)** / 보조 = 공통 × **무기 레벨**
- 보조 최대 탄약 = 무기 기본(`max_charges`) + **격납고(시설)** 가산
- 궤도 방벽 조각은 피격 시 영구 파괴(재생 없음). 전량 파괴 시 슬롯 소모
- HUD: `WeaponLoadoutHud` + `HexModuleFrame` (우측 패널 `WeaponBox` 안) · 아이콘은 `assets/svg/weapons/` (`icon_path` on weapon definition)

### 조작 요약 (전투 중)

| 입력 | 동작 |
|------|------|
| WASD / 화살 | 이동 |
| 발사 | 주무기 자동/홀드 (기존 무기 입력) |
| **Z** | 메인 ↔ 예비 스왑 |
| **X** | 미보유 주무기 픽업 차단 토글 |
| **C** | XP 준비 시 플레이어 오그먼트 오픈 |
| **ESC** | 수동 일시정지 토글 (오퍼 pause와 분리) |

## PlayerAugmentApplier

`augment_added` / `augments_cleared` / `refresh()` 시:

- `MOVE_SPEED` → `MoveComponent.velocity_multiplier` (**씬 기본 배수 × 오그먼트 × 엔진 시설** 합산도 여기서)
- `FIRE_RATE` / `WEAPON_DAMAGE` → 각 WeaponSystem 전역 배수
- `UPGRADE_MAIN_WEAPON` → 현재 장착 주무기 레벨 상승
- `UPGRADE_AUXILIARY_WEAPON` → 선택한 슬롯에 장착된 보조무기 레벨 상승

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).

## 함선 시설 (`ShipFacilityRegistry` / `ShipFacilityApplier`)

공통 스탯만 강화한다. 무기 고유 성능·공격 방식은 오그먼트 담당이며 시설 코드에 무기 id 분기는 없다.

| id | 이름 | 효과 |
|----|------|------|
| `weapon_room` | 무기실 | 주무기 공통 공격력 배율 (교체해도 유지, 보조 무영향) |
| `hangar` | 격납고 | 보조무기 최대 탄약 가산 |
| `engine` | 엔진 | 이동속도 배율 |
| `hull` | 선체 | 최대 선체 내구도(기존 HP) 가산 |
| `radar` | 레이더 | 픽업 수집 반경 배율 |
| `shield` | 실드 | 최대 실드 가산 |

- 수치는 `resources/facilities/definitions/*.tres`의 `level_values` 표 (index 0 = Lv.1 = 무효과). **현재 값은 임시 플레이스홀더**이며 표 길이가 곧 상한
- 모든 시설 시작 레벨 **Lv.1**. 레벨 변경 경로는 `upgrade_facility(id)` 하나뿐이고, 그것을 부르는 인게임 경로는 **시설 오그먼트 선택**뿐이다
- 격납고: 새 보조무기는 계산된 최대치로 시작. 이미 장착 중이면 **늘어난 분만** 남은 탄약에 가산(완전 회복 아님). 소진 시 슬롯 제거 규칙은 그대로
- 궤도 방벽은 탄약 카운터가 없어(`get_consumable_max()` = -1) 격납고 보너스를 받지 않음
- 선체: `StatsComponent`에 최대 체력 필드가 없어 `ShipFacilityApplier`가 최대 선체 = `기본 + 선체 가산`(최소 1)을 들고 있고, 최대치 증가분만큼 현재 선체도 함께 증가. 그 밖의 회복 수단 없음
- 레이더: 수집 반경 = `ExperienceCollector` 기본 반경(36) × 레이더 배율. 획득량·드롭률은 무영향. 무기 픽업도 같은 Area를 쓰므로 함께 넓어짐
- 실드: `ShieldComponent`가 보유. 최대 실드 = `기본(0) + 실드 가산`, 최대치 증가분만큼 현재 실드도 충전. 리필을 부르는 곳은 아직 없음
- UI: `ShipPanel`(오른쪽 패널)은 읽기 전용 — 레벨·스탯을 직접 바꾸지 않음. 칩 클릭·마우스 오버는 상세 표시 전용

## 시설 오그먼트 (`PlayerAugmentKind.Kind.UPGRADE_FACILITY`)

- `resources/player_augments/facilities/*.tres` 6장이 플레이어 오퍼 풀에 함께 들어감 (`gameplay.tscn`의 `player_augment_pool`)
- 카드는 `facility_id`·표시 이름·설명·아이콘·`facility_level_gain`만 보유. 레벨별 효과·상한은 시설 정의가 정본
- 상한에 닿은 시설 카드는 `AugmentOfferController._is_player_augment_available()`에서 제외됨
- 선택 시 `AugmentOfferController`가 `upgrade_facility()`만 호출하고, 스탯 적용·UI 갱신은 `facility_level_changed` 구독자가 처리

## 선체 · 실드

- `ShieldComponent`(함선 자식): `get_current_shield()` / `get_max_shield()` / `add_shield(amount)`(최대치 +, 현재도 같은 양 상승) / `restore_shield(amount)`(현재만 충전, 최대 이내) / `absorb_damage(damage)`, 시그널 `shield_changed(current, max)` · `shield_absorbed(damage)`
- **실드 게이트**: `HurtComponent`가 체력을 깎기 전에 `absorb_damage()`를 부른다. 현재 실드 ≥ 1이면 그 피해 이벤트 전체를 막고(실드 = `max(0, 실드 − 피해)`) 선체는 그대로. 실드 0일 때만 선체가 깎인다
- 무적시간은 여전히 **없다**. 한 프레임에 여러 히트박스가 겹치면 각각 별개 이벤트로 처리된다
- HUD: 좌측 패널 `ShipStatusHud`가 `HULL 현재/최대`(민트)·`SHIELD 현재/최대`(보라)를 표시. 함선 파괴 시 `—`
