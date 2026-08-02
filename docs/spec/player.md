# 플레이어

## Ship (`player_ship/ship.gd`)

- 그룹: `"player"`
- `PlayerAugmentRegistry` 주입 → `PlayerAugmentApplier.initialize` / `ShipFacilityApplier.initialize`
- `WeaponMount` 아래 모든 `WeaponSystem` 수집
- 무기 `fired` → `ScaleComponent.tween_scale()`

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

## 무기 (통합 장착 베이)

- `PlayerWeaponLoadout`: `max_equipped_weapon_count`(기본 3)개의 장착 베이. 주/보조·메인/예비 구분 없음
- 시작: 블래스터가 베이 0 (무기 Lv.1)
- 장착된 무기는 각자 쿨다운으로 **동시에** 작동. 탄약·소진 삭제 없음
- 성장은 `weapon_id`별 중앙 상태(`WeaponProgressState`: level, trait_ranks)
- **무기 획득·레벨·특성·기록 복원**은 레벨업 **증강 선택**으로만 처리 (필드 무기 드롭 없음)
- 빈 베이면 신규/복원 자동 장착. 만석이면 증강 화면에서 교체 대상 선택 → 기존 무기는 기록 보존
- 기록 복원 시 레벨을 추가로 올리지 않음. 레벨+1은 `WEAPON_LEVEL` 증강만
- 무기실: 전 장착 무기 피해. 격납고: 효과 미정. Z/X·필드 교체 UI 없음
- 궤도 방벽 조각은 피격 시 파괴될 수 있으나 슬롯은 유지
- HUD: `WeaponLoadoutHud` — 장착 베이 코어 육각(+특성 위성)·기록 스크롤·상세 패널

### 조작 요약 (전투 중)

| 입력 | 동작 |
|------|------|
| WASD / 화살 | 이동 |
| 발사 | 장착 무기 자동 사격 |
| **C** | XP 준비 시 플레이어 오그먼트 오픈 |
| **ESC** | 수동 일시정지 토글 (오퍼 pause와 분리) |

## PlayerAugmentApplier

`PlayerAugmentRegistry.augments_changed` / `refresh()` 시 설치된 모듈 전체를 다시 계산한다.

- `MOVE_SPEED` → `MoveComponent.velocity_multiplier` (**씬 기본 배수 × 스탯 모듈 × 엔진 모듈 효과** 합산도 여기서)
- `FIRE_RATE` / `WEAPON_DAMAGE` → 각 WeaponSystem 전역 배수
- `WEAPON_TRAIT` → 설치 시 `PlayerWeaponLoadout.add_or_upgrade_weapon_trait` (전투 효과 스캐폴드)
- 무기 레벨은 필드 픽업만 올린다 (오그먼트로 레벨업하지 않음)

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).

## 함선 부위와 모듈 슬롯 (`PlayerAugmentRegistry` / `ShipFacilityApplier`)

모든 플레이어 증강은 아래 함선 부위 하나를 대상으로 하며 그 부위의 모듈 슬롯 하나를 차지한다.

| id | 이름 | 효과 |
|----|------|------|
| `weapon_room` | 무기실 | 연사·공격력 스탯 모듈, **장착 무기 공통 공격력** 모듈 |
| `hangar` | 격납고 | 슬롯/UI 유지 · **효과 미정** (구 탄약 효과 폐기) |
| `engine` | 엔진 | 이동속도 모듈 |
| `hull` | 선체 | 최대 선체 내구도 가산 모듈 |
| `radar` | 레이더 | 픽업 수집 반경 모듈 |
| `shield` | 실드 | 최대 실드 가산 모듈 |

- 모든 부위는 빈 슬롯 1개로 시작하며, 플레이어 오퍼 하나를 소비해 최대 3개까지 확장할 수 있다
- 증강 선택 시 빈 슬롯에 설치한다. 슬롯이 가득 찼으면 교체 창에서 기존 모듈 하나를 선택하며, 취소하면 오퍼로 돌아간다
- 동일 모듈의 중복 설치와 효과 중첩을 허용한다
- `FACILITY_EFFECT` 모듈의 누적 수치는 `resources/facilities/definitions/*.tres`의 `module_count_values`를 사용한다. index 0은 0개 설치의 중립값이고 index 1~3이 설치 개수별 누적값이다
- 격납고: 슬롯·카드는 유지하되 **전투 효과 미정** (구 보조 탄약 보너스는 폐기)
- 선체: `StatsComponent`에 최대 체력 필드가 없어 `ShipFacilityApplier`가 최대 선체 = `기본 + 선체 가산`(최소 1)을 들고 있고, 최대치 증가분만큼 현재 선체도 함께 증가. 그 밖의 회복 수단 없음
- 레이더: 수집 반경 = `ExperienceCollector` 기본 반경(36) × 레이더 배율. **경험치 오브 등 필드 픽업**만 해당. 무기 필드 드롭은 없음. 증강 무기 등장 확률과 무관

- 실드: `ShieldComponent`가 보유. 최대 실드 = `기본(0) + 실드 가산`, 최대치 증가분만큼 현재 실드도 충전. 리필을 부르는 곳은 아직 없음
- 전투 중 `ShipPanel`은 읽기 전용이다. 플레이어 증강 오퍼 안의 `ShipPanel`만 확장 가능한 부위를 선택할 수 있다
- 슬롯은 숫자 카운터 대신 둥근 사각 프레임으로 표시하며, 설치 모듈의 `icon`을 프레임 안에 그린다

## 플레이어 증강 오퍼

- 화면 상단에 증강 3개, 구분선 아래에 함선 부위 UI를 표시한다
- 카드 포커스·호버가 바뀌면 그 카드의 `facility_id`에 해당하는 함선 부위를 하이라이트한다
- 카드 대신 확장 가능한 함선 부위를 선택하면 해당 부위의 빈 슬롯을 1개 늘리고 오퍼를 종료한다
- 확장 부위에 키보드 포커스 또는 마우스 호버가 들어오면 추가될 다음 슬롯이 점멸한다
- 카드 3개와 확장 가능한 부위 6개는 방향키·Tab으로 이동하고 `ui_accept`로 선택할 수 있다
- 모든 실제 플레이어 오퍼 리소스는 유효한 `facility_id`를 가져야 한다
- 적 증강 오퍼는 함선 UI 없이 기존 3지선다를 유지한다

## 선체 · 실드

- `ShieldComponent`(함선 자식): `get_current_shield()` / `get_max_shield()` / `add_shield(amount)`(최대치 +, 현재도 같은 양 상승) / `restore_shield(amount)`(현재만 충전, 최대 이내) / `absorb_damage(damage)`, 시그널 `shield_changed(current, max)` · `shield_absorbed(damage)`
- **실드 게이트**: `HurtComponent`가 체력을 깎기 전에 `absorb_damage()`를 부른다. 현재 실드 ≥ 1이면 그 피해 이벤트 전체를 막고(실드 = `max(0, 실드 − 피해)`) 선체는 그대로. 실드 0일 때만 선체가 깎인다
- 무적시간은 여전히 **없다**. 한 프레임에 여러 히트박스가 겹치면 각각 별개 이벤트로 처리된다
- HUD: 좌측 패널 `ShipStatusHud`가 `HULL 현재/최대`(민트)·`SHIELD 현재/최대`(보라)를 표시. 함선 파괴 시 `—`
