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

# 무기 (통합 장착 베이)

- `PlayerWeaponLoadout`: `max_equipped_weapon_count`(기본 3)개의 장착 베이. 주/보조·메인/예비 구분 없음
- 시작: 블래스터가 베이 0 (무기 Lv.1)
- 장착된 무기는 각자 쿨다운으로 **동시에** 작동. 탄약·소진 삭제 없음
- 성장은 `weapon_id`별 중앙 상태(`WeaponProgressState`: level, trait_ranks). **장착 중인 무기만** 보유
- **무기 획득·레벨·특성**은 레벨업 **증강 선택**으로만 처리 (필드 무기 드롭 없음)
- 빈 베이면 신규 자동 장착. 만석이면 증강 화면에서 교체 → **피교체 무기 성장(레벨·특성) 완전 삭제**
- 같은 무기를 다시 얻으면 기본 레벨·특성 없음으로 시작 (교체로 뺀 성장은 보존하지 않음)
- 무기실: 전 장착 무기 피해. 격납고: 효과 미정
- HUD: `WeaponLoadoutHud` — 동일 크기 장착 베이 헥스 가로 행. 템플릿(`%BaySlotTemplate` · `%ModuleHexTemplate` · `%SelectedWeaponHex`) 복제. 호버/클릭 포커스 → 하단 `선택된 무기` | `장착된 모듈` + 설명(전투 수치는 인게임 비표시)
- 증강 리롤: `AugmentOfferController.max_reroll_count`(임시 기본 2) · 런당 `remaining_reroll_count`

## 현재 무기 목록 (`gameplay.tscn` 획득 풀)

| id | 표시명 | 현재 역할 |
|----|--------|-----------|
| `main_blaster` | 블래스터 | 좌우 교대 발사형. 시작 시 베이 0에 Lv.1 장착 |
| `main_laser` | 레이저 | 연속 빔형 |
| `main_shotgun` | 샷건 | 부채꼴 다중 펠릿 근거리 화력 |
| `aux_test_cannon` | 보조 캐넌 | 연두빛 탄환 자동 발사 |
| `plasma_bomb` | 플라즈마 폭탄 | 지연 폭발·범위 피해 |
| `aux_homing_missile` | 유도탄 | 가까운 적을 추적 |
| `aux_orbital_barrier` | 궤도 방벽 | 주변을 돌며 탄막 소멸 + 적 접촉 피해. HP 없음 |

### 기본 전투 수치 (WeaponSystem 씬 · Lv.1 · 배율 1.0)

정본은 각 `player_ship/weapons/*_weapon_system.tscn` 익스포트. 레벨·시설·스탯 모듈이 곱해지면 실효값은 달라진다. **인게임 STATUS에는 표시하지 않는다.**

| 무기 | 핵심 수치 |
|------|-----------|
| 블래스터 | 피해 10 · 간격 0.15초 · 탄속 200 |
| 레이저 | 틱피해 3 · 틱 0.1초 |
| 샷건 | 펠릿 피해 4 × 5발 · 간격 0.42초 · 확산 36° · 펠릿 속 220 |
| 보조 캐넌 | 피해 9 · 간격 0.8초 · 탄속 190 |
| 플라즈마 폭탄 | 피해 32 · 간격 1.2초 · 탄속 66 · 신관 1.0초 · 반경 32 |
| 유도탄 | 피해 14 · 간격 1.1초 · 탄속 150 · 선회 5.5 · 재탐색 0.15초 |
| 궤도 방벽 | 접촉피해 6 · 반경 22 · 회전 2.8 |

- 위 7종 모두 `WEAPON_ACQUIRE` / `WEAPON_LEVEL` 카드가 Gameplay 플레이어 증강 풀에 등록되어 있다
- 무기 정의 파일이 존재하더라도 `gameplay.tscn`의 획득 풀에 없으면 현재 플레이 가능한 무기 목록에 포함하지 않는다

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
- 무기 레벨·특성은 증강 선택으로만 성장 (필드 픽업 없음)

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).

## 함선 부위와 모듈 슬롯 (`PlayerAugmentRegistry` / `ShipFacilityApplier`)

시설·스탯 모듈은 아래 함선 부위 하나를 대상으로 하며 그 부위의 모듈 슬롯 하나를 차지한다.
무기 획득·레벨·특성 증강은 시설 슬롯을 소모하지 않는다.

| id | 이름 | 효과 |
|----|------|------|
| `weapon_room` | 무기실 | 연사·공격력 스탯 모듈, **장착 무기 공통 공격력** 모듈 |
| `hangar` | 격납고 | 슬롯/UI 유지 · **효과 미정** |
| `engine` | 엔진 | 이동속도 모듈 |
| `hull` | 선체 | 최대 선체 내구도 가산 모듈 |
| `radar` | 레이더 | 픽업 수집 반경 모듈 |
| `shield` | 실드 | 최대 실드 가산 모듈 |

- 모든 부위는 빈 슬롯 1개로 시작하며, 플레이어 오퍼 하나를 소비해 최대 3개까지 확장할 수 있다
- 증강 선택 시 빈 슬롯에 설치한다. 슬롯이 가득 찼으면 교체 창에서 기존 모듈 하나를 선택하며, 취소하면 오퍼로 돌아간다
- 동일 모듈의 중복 설치와 효과 중첩을 허용한다
- `FACILITY_EFFECT` 모듈의 누적 수치는 `resources/facilities/definitions/*.tres`의 `module_count_values`를 사용한다. index 0은 0개 설치의 중립값이고 index 1~3이 설치 개수별 누적값이다
- 격납고: 슬롯·카드는 유지하되 **전투 효과 미정**
- 선체: `StatsComponent`에 최대 체력 필드가 없어 `ShipFacilityApplier`가 최대 선체 = `기본 + 선체 가산`(최소 1)을 들고 있고, 최대치 증가분만큼 현재 선체도 함께 증가. 그 밖의 회복 수단 없음
- 레이더: 수집 반경 = `ExperienceCollector` 기본 반경(36) × 레이더 배율. **경험치 오브 등 필드 픽업**만 해당. 증강 무기 등장 확률과 무관

- 실드: `ShieldComponent`가 보유. 최대 실드 = `기본(0) + 실드 가산`, 최대치 증가분만큼 현재 실드도 충전. 리필을 부르는 곳은 아직 없음
- 전투 중 `ShipPanel`은 읽기 전용이다. 플레이어 증강 오퍼 안의 `ShipPanel`만 확장 가능한 부위를 선택할 수 있다
- 슬롯은 숫자 카운터 대신 둥근 사각 프레임으로 표시하며, 설치 모듈의 `icon`을 프레임 안에 그린다

## 플레이어 증강 오퍼

- 화면 상단에 증강 3개, 구분선 아래에 함선 부위 UI를 표시한다
- `STAT_MULTIPLIER` / `FACILITY_EFFECT` 카드 포커스·호버는 대상 `facility_id` 부위를 하이라이트한다. 무기 Kind 카드는 시설 하이라이트를 강제하지 않는다
- 카드 대신 확장 가능한 함선 부위를 선택하면 해당 부위의 빈 슬롯을 1개 늘리고 오퍼를 종료한다
- 확장 부위에 키보드 포커스 또는 마우스 호버가 들어오면 추가될 다음 슬롯이 점멸한다
- 카드 3개와 확장 가능한 부위 6개는 방향키·Tab으로 이동하고 `ui_accept`로 선택할 수 있다
- 스탯·시설 모듈 리소스만 유효한 `facility_id`를 가진다. 무기 Kind는 시설 슬롯에 설치되지 않는다
- 적 증강 오퍼는 함선 UI 없이 기존 3지선다를 유지한다

## 선체 · 실드

- `ShieldComponent`(함선 자식): `get_current_shield()` / `get_max_shield()` / `add_shield(amount)`(최대치 +, 현재도 같은 양 상승) / `restore_shield(amount)`(현재만 충전, 최대 이내) / `absorb_damage(damage)`, 시그널 `shield_changed(current, max)` · `shield_absorbed(damage)`
- **실드 게이트**: `HurtComponent`가 체력을 깎기 전에 `absorb_damage()`를 부른다. 현재 실드 ≥ 1이면 그 피해 이벤트 전체를 막고(실드 = `max(0, 실드 − 피해)`) 선체는 그대로. 실드 0일 때만 선체가 깎인다
- 무적시간은 여전히 **없다**. 한 프레임에 여러 히트박스가 겹치면 각각 별개 이벤트로 처리된다
- HUD: 좌측 패널 `ShipStatusHud`가 `HULL 현재/최대`(민트)·`SHIELD 현재/최대`(보라)를 표시. 함선 파괴 시 `—`
