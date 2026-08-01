# Feature: 함선 시설 강화 · 오른쪽 함선 UI

> 2026-08-01 이후 시설 레벨 시스템은 [증강 모듈 슬롯](augment-module-slots.md)으로 대체됐다. 아래 내용은 기존 시설 UI와 효과 채널의 설계 이력이다.

## 목적

함선 내부 **시설**로 **공통 스탯만** 강화한다. 무기별 고유 성능·공격 방식은 **오그먼트**가, 무기 획득·교체는 **드롭**이 담당하며 시설은 그 경계를 넘지 않는다.

## 역할 구분

| 축 | 담당 | 예 |
|---|---|---|
| 함선 시설 | 공통 수치 | 주무기 공격력, 보조 최대 탄약, 이동속도, 최대 선체, 수집 반경, 최대 실드 |
| 주무기 오그먼트 | 무기별 고유 성능 | 관통·도탄·발사체 수, 빔 굵기·분기 |
| 무기 드롭 | 획득·교체 | 주무기 레벨, 보조 리필 |

시설 코드에는 **무기 id 분기를 넣지 않는다**. 무기실은 어떤 주무기가 장착돼 있어도 같은 인터페이스(공통 배율 채널)만 사용한다.

## 시설 (이번 범위 6종)

| id | 이름 | 효과 | 적용 지점 |
|---|---|---|---|
| `weapon_room` | 무기실 | 주무기 공통 공격력 배율 | `PlayerWeaponLoadout` → 주무기 슬롯의 `WeaponSystem.set_facility_damage_multiplier` |
| `hangar` | 격납고 | 보조무기 최대 탄약 가산 | `WeaponSystem.set_consumable_capacity_bonus` |
| `engine` | 엔진 | 이동속도 배율 | `PlayerAugmentApplier`의 이동속도 합산식 |
| `hull` | 선체 | 최대 선체 내구도(기존 HP) 가산 | `ShipFacilityApplier` (StatsComponent) |
| `radar` | 레이더 | 픽업 수집 반경 배율 | `ExperienceCollectorComponent.collection_radius` |
| `shield` | 실드 | 최대 실드 가산 | `ShipFacilityApplier` → `ShieldComponent` |

## 동작 규칙

1. 시설 레벨은 **레지스트리(`ShipFacilityRegistry`)** 가 보유하고, 변경 시 `facility_level_changed`를 emit한다
2. 레벨 변경 → 적용자(`ShipFacilityApplier`)가 로드아웃·이동·체력을 갱신하고, UI(`ShipPanel`)는 같은 시그널로 즉시 다시 그린다
3. **무기실**: 주무기 슬롯 전용 배율 채널. 주무기를 교체해도 유지되고, 보조무기와 무기 고유 성능은 건드리지 않는다
4. **격납고**: 최대 탄약 = `무기 기본(max_charges)` + `격납고 가산`. 새로 획득한 보조무기는 계산된 최대치로 시작한다. 이미 장착 중이면 **늘어난 만큼만** 남은 탄약에 더한다(완전 회복 아님). 탄약 0 → 슬롯 제거 규칙은 그대로
5. **엔진**: 최종 이동속도 = `씬 기본 배수 × 오그먼트 배율 × 엔진 배율`. 강화 즉시 반영
6. **선체**: 최대 선체 = `기본 최대 선체 + 선체 가산`(최소 1). 기존 체력 시스템에 최대 체력 개념이 없어, **늘어난 최대치만큼 현재 선체도 함께 올린다**. 그 밖의 회복(자동 수리·회복 아이템·처치 회복)은 없다
7. **레이더**: 수집 반경 = `함선 기본 반경 × 레이더 배율`. 경험치 오브가 끌려오는 범위(`ExperienceCollectorComponent`)만 넓히고, 획득량·드롭률은 바꾸지 않는다
8. **실드**: 최대 실드 = `기본 최대 실드(0) + 실드 가산`. 늘어난 최대치만큼 현재 실드도 함께 찬다. 리필 조건은 정하지 않고 `restore_shield(amount)` 인터페이스만 제공한다
9. **실드 게이트**: 피해 직전 현재 실드가 1 이상이면 `HurtComponent`가 그 피해 이벤트 전체를 실드로 흡수하고 선체에 넘기지 않는다. 실드는 `max(0, 실드 − 피해)`가 되고, 다음 피해 이벤트는 실드 0이므로 선체가 받는다. **새 무적시간은 만들지 않는다** — 한 프레임에 여러 히트박스가 겹치면 각각 별개 이벤트다
10. 시설 레벨을 올리는 인게임 경로는 **오그먼트 선택뿐**이다. UI는 읽기 전용이고, 레벨 변경 경로는 `ShipFacilityRegistry.upgrade_facility()` 하나뿐이다

## 시설 오그먼트

- `PlayerAugmentKind.Kind.UPGRADE_FACILITY`(=6) 카드 6장이 기존 플레이어 오그먼트 풀에 함께 들어간다 (`resources/player_augments/facilities/*.tres`)
- 카드는 대상 `facility_id`·표시 이름·설명·아이콘·`facility_level_gain`만 갖는다. **레벨별 효과값과 최대 레벨은 시설 정의(`.tres`)가 정본**이라 카드에 중복 수치를 두지 않는다
- `AugmentOfferController._is_player_augment_available()`이 `can_upgrade_facility()`로 거르므로 **상한에 닿은 시설 카드는 선택지에서 사라진다**
- 카드를 고르면 `AugmentOfferController`가 레지스트리 레벨만 올리고, 스탯 재계산(`ShipFacilityApplier`)과 STATUS UI 갱신(`ShipPanel`)은 `facility_level_changed`를 듣는 쪽이 알아서 한다

## 오른쪽 UI

```text
ShipPanel
├─ ShipDiagram    (함선 그림, 별도 씬)
├─ FacilityLinks  (칩 ↔ 함선 하드포인트 배선, 함선 그림 위·칩 아래)
├─ WeaponRoom  Hangar   (1행 좌/우)
├─ Engine      Hull     (2행 좌/우)
├─ Radar       Shield   (3행 좌/우)
└─ DetailBox / FacilityDetail (선택한 시설의 현재/다음 레벨 효과)
```

- 함선 그림을 가운데(66×79)에 두고 시설 칩 6개를 좌우 3행으로 배치한다. 각 칩은 배선으로 함선 위 하드포인트(작은 사각 노드)와 이어지고, 선택된 칩의 배선·노드만 밝게 표시한다
- 시설 칩은 **아이콘 + 이름 + 현재 레벨 + 현재 효과값 + 강화 가능 표시**(`▲` 강화 가능 / `MAX` 상한 / 표시 없음 = 수치 미설정). 아이콘은 시설 정의(`icon`)가 들고 있고 UI에서 색만 입힌다
- 칩을 클릭하거나 마우스를 올리면 하단 상세 박스가 `무기실 Lv.2 : 주무기 공격력 증가 / 현재 ×1.15 → Lv.3 ×1.30` 형태로 바뀐다. 선택은 상세 표시 전용이며 강화되지 않는다
- 우측 패널이 좁아(162×340) 기존 무기 HUD는 테두리 박스(`WeaponBox`)로 묶고 모듈 크기를 줄였다 (메인 88→56, 예비 64→44, 보조 54→34, 보유 36→22). HUD 경로도 `.../VBox/WeaponBox/Margin/WeaponLoadoutHud`로 한 단계 깊어졌다
- 6칩이 들어가도록 우측 패널 세로 여백을 18→10, VBox 간격을 6→4로 줄였다. 현재 내용 높이는 337 / 가용 340이라 여유가 거의 없다 — 항목을 더 넣기 전에 스모크 테스트의 fit 검사를 먼저 본다
- 세 패널(좌·플레이필드·우)에는 `NeonCornerFrame`이 모서리 브래킷을 그린다 (장식 전용, 입력 없음)

## 선체 · 실드 HUD

좌측 패널 `ShipStatusHud`(`XP·위협 바 아래`)가 전투 중 자원량을 보여준다. STATUS 칩의 시설 레벨과 구분되도록 좌측에 둔다.

- `HULL  현재 / 최대` — 민트(0.2, 1, 0.68), 최대치는 `ShipFacilityApplier.get_max_hull()`
- `SHIELD 현재 / 최대` — 보라(0.6, 0.45, 1), `ShieldComponent`
- 기존 XP(시안)·위협(마젠타) 바와 같은 배경 스타일·10px 높이를 쓴다
- 함선이 파괴되면 `—`로 바꾼다 (HUD가 사라진 노드를 붙들지 않게)

## Acceptance Criteria

- [ ] 오른쪽 UI에 함선 그림과 6개 시설(무기실·격납고·엔진·선체·레이더·실드)이 보이고 각 현재 레벨·효과가 표시된다
- [ ] 시설 레벨 변경 시 UI가 즉시 갱신된다
- [ ] 시설은 STATUS UI에서 강화할 수 없고, 오그먼트 선택으로만 오른다
- [ ] 최대 레벨 시설의 오그먼트 카드는 선택지에 나오지 않는다
- [ ] 무기실 레벨이 주무기 공격력에 적용되고, 주무기를 교체해도 유지된다
- [ ] 무기실이 보조무기 공격력·주무기 고유 공격 방식을 바꾸지 않는다
- [ ] 격납고 레벨이 보조 최대 탄약에 적용되고, 탄약 0이면 기존대로 슬롯이 비워진다
- [ ] 엔진 레벨이 이동속도, 선체 레벨이 최대 선체에 즉시 적용된다
- [ ] 레이더 레벨이 픽업 수집 반경에 적용된다
- [ ] 실드 레벨이 최대 실드에 적용되고, 실드가 1 이상이면 초과 피해가 선체로 넘어가지 않는다
- [ ] 실드가 0일 때만 선체가 피해를 받는다
- [ ] 전투 화면에서 현재/최대 선체와 실드를 확인할 수 있다
- [ ] UI가 스탯·레벨을 직접 수정하지 않는다
- [ ] 시설 수치가 `resources/facilities/definitions/*.tres` 한곳에만 존재한다
- [ ] 우측 패널 내용이 패널 가용 높이를 넘지 않는다

## 미확정 (설계 결정 필요)

- **밸런스 수치·상한**: `.tres`의 `level_values`는 **임시 플레이스홀더**다. 표 길이가 곧 현재 상한이며, 이 표만 고치면 코드 변경 없이 바뀐다

  | 시설 | 임시 표 (Lv.1→) |
  |---|---|
  | 무기실 | ×1.00 / ×1.15 / ×1.30 / ×1.45 |
  | 격납고 | +0 / +4 / +8 / +12 |
  | 엔진 | ×1.00 / ×1.10 / ×1.20 / ×1.30 |
  | 선체 | +0 / +1 / +2 / +3 |
  | 레이더 | ×1.00 / ×1.15 / ×1.30 / ×1.45 |
  | 실드 | +0 / +1 / +2 / +3 |

- **선체·실드 스케일**: 기본 최대 선체가 1(원샷 사망)이라 가산치도 1 단위로 잡아 뒀다. 기본 HP를 올리면 두 표를 함께 다시 잡아야 한다
- **실드 리필 수단 없음**: `restore_shield()`를 부르는 곳이 아직 없다. 픽업·처치 충전·시간 재생 중 무엇으로 할지는 별도 결정
- **궤도 방벽**: 탄약 카운터가 아니라 조각 HP를 소모하는 방식(`get_consumable_max()` = -1)이라 격납고 보너스를 **적용하지 않는다**. 조각 수·내구도 중 무엇으로 환산할지는 미정
- **레이더와 무기 픽업**: 수집 반경은 경험치 오브뿐 아니라 무기 픽업 흡수 판정도 함께 넓힌다(같은 콜리전 레이어). 요구대로 둘 다 적용 중이며, 분리 여부는 미정
- **시설 카드 등장 빈도**: 오퍼는 가중치 없이 균등 셔플이라 후보가 11장으로 늘면서 기존 스탯 카드가 나올 확률이 낮아졌다. 가중치가 필요한지는 플레이 후 판단
- 창고 · 반응로 · 수리실 · 드론실은 이번 범위 밖

## 구현 메모

- 데이터: `resources/facilities/ship_facility_definition.gd` (`level_values` 표 + 효과 종류)
- 상태: `ship_facility_registry.gd` (Gameplay 자식, `upgrade_facility` / `get_facility_level` / `get_facility_effect`)
- 적용: `components/ship_facility_applier.gd` (함선 자식)
- 실드: `components/shield_component.gd` + `components/hurt_component.gd`의 게이트 분기
- 오그먼트: `resources/player_augments/facilities/*.tres`, `augment_offer_controller.gd`
- UI: `menus/ship_panel.*`, `menus/ship_facility_module.*`, `menus/ship_facility_links.gd`, `menus/ship_diagram.tscn`, `menus/ship_status_hud.gd`
- 패널 장식: `menus/neon_corner_frame.gd`
- 아이콘: `assets/svg/facilities/facility_*.svg` (흰색 실루엣, 정의 `.tres`가 참조)
- 테스트: `tests/ship_facility_upgrade_test.gd`
- `menus/ship_panel.tscn`은 ASCII만 유지한다 (표시 문자열은 스크립트가 채운다)

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-01 | 초기: 시설 4종 + 오른쪽 함선 UI, 수치는 플레이스홀더 |
| 2026-08-01 | 목업 반영: 시설 아이콘·배선·상세 박스, 무기 HUD 박스화, 패널 모서리 브래킷 |
| 2026-08-01 | 레이더(수집 반경)·코어(최대 체력 배율) 추가 → 시설 6종 |
| 2026-08-01 | 장갑→선체, 코어→실드(별도 자원 + 실드 게이트). 시설 오그먼트 6종으로 레벨업 경로 연결, 좌측에 선체·실드 HUD 추가 |
