# Tasks: ship-facility-upgrades

> 시설 레벨 관련 작업은 [augment-module-slots tasks](augment-module-slots-tasks.md)에서 모듈 슬롯 방식으로 대체됐다.

## Task 1 — 시설 데이터·상태

- 목적: 레벨별 효과값 표와 런타임 레벨 보관
- 수정 예상: `resources/facilities/ship_facility_definition.gd`, `resources/facilities/definitions/*.tres`, `ship_facility_registry.gd`, `gameplay.tscn`
- 완료: 수치가 `.tres` 한곳에 있고 `upgrade_facility` / `get_facility_level` / `get_facility_effect`가 시그널과 함께 동작

## Task 2 — 공통 스탯 적용

- 목적: 무기실·격납고·엔진·장갑을 기존 계산식에 연결 (무기 id 분기 없이)
- 수정 예상: `components/ship_facility_applier.gd`, `player_ship/player_weapon_loadout.gd`, `player_ship/weapons/weapon_system.gd`, `player_ship/weapons/auxiliary_cannon_weapon_system.gd`, `player_ship/weapons/homing_missile_weapon_system.gd`, `components/player_augment_applier.gd`, `player_ship/ship.*`
- 완료: 주무기 교체 후에도 무기실 보너스 유지, 보조 탄약 소진 규칙 유지, 이동속도·최대 체력 즉시 반영

## Task 3 — 오른쪽 함선 UI

- 목적: 함선 그림 + 시설 4칩 + 선택 상세
- 수정 예상: `menus/ship_panel.*`, `menus/ship_facility_module.*`, `menus/ship_diagram.tscn`, `fonts/ship_panel_detail_label_settings.tres`, `world.tscn`, `menus/weapon_loadout_hud.gd`
- 완료: 레벨 변경 시 즉시 갱신되고, 패널이 우측 패널 안에 들어가며, UI가 스탯을 직접 바꾸지 않음

## Task 5 — 목업 스타일 정리

- 목적: 제시된 목업(함선 중심 + 아이콘 칩 + 배선 + 상세 박스)에 맞춰 우측 패널 시각 정리
- 수정 예상: `assets/svg/facilities/*`, `resources/facilities/*`, `menus/ship_facility_links.gd`, `menus/ship_panel.*`, `menus/ship_facility_module.*`, `menus/ship_diagram.tscn`, `world.tscn`
- 완료: 칩에 시설 아이콘·레벨·효과가 3줄로 표시되고, 선택 칩의 배선·하드포인트가 강조되며, 무기 HUD가 테두리 박스 안으로 들어가고도 패널 높이를 넘지 않음

## Task 6 — 레이더·코어 추가 (시설 6종)

- 목적: 목업의 6칸 배치를 채우는 공통 스탯 2종
- 수정 예상: `resources/facilities/ship_facility_definition.gd`, `resources/facilities/definitions/{radar,core}.tres`, `assets/svg/facilities/facility_{radar,core}.svg`, `components/ship_facility_applier.gd`, `player_ship/ship.tscn`, `gameplay.tscn`, `menus/ship_panel.tscn`
- 완료: 레이더가 `ExperienceCollectorComponent.collection_radius`를, 코어가 `(기본 + 장갑) × 배율` 최대 체력을 갱신하고, 6칩이 우측 패널 가용 높이 안에 들어감

## Task 7 — 패널 모서리 브래킷

- 목적: 목업의 SF 프레임 느낌
- 수정 예상: `menus/neon_corner_frame.gd`, `world.tscn`
- 완료: 좌·플레이필드·우 패널 모서리에 브래킷이 그려지고 입력·레이아웃에 영향 없음

## Task 8 — 선체·실드로 개명 + 실드 자원

- 목적: 장갑→선체(가산), 코어→실드(별도 방어 자원 + 실드 게이트)
- 수정 예상: `resources/facilities/ship_facility_definition.gd`, `resources/facilities/definitions/{hull,shield}.tres`, `assets/svg/facilities/facility_{hull,shield}.svg`, `components/shield_component.gd`, `components/hurt_component.gd`, `components/ship_facility_applier.gd`, `player_ship/ship.*`, `menus/ship_panel.tscn`, `gameplay.tscn`
- 완료: 실드 ≥ 1이면 초과 피해가 선체로 넘어가지 않고, 실드 0일 때만 선체가 깎이며, 새 무적시간이 생기지 않음

## Task 9 — 시설 오그먼트 연결

- 목적: 시설 레벨을 올리는 유일한 인게임 경로를 오그먼트 선택으로 확정
- 수정 예상: `resources/player_augments/player_augment_kind.gd`, `resources/player_augments/player_augment.gd`, `resources/player_augments/facilities/*.tres`, `augment_offer_controller.gd`, `components/player_augment_applier.gd`, `menus/augment_selection_overlay.gd`, `gameplay.tscn`
- 완료: 카드 선택 시 레벨·효과·UI가 즉시 반영되고, 최대 레벨 시설 카드는 선택지에 나오지 않음

## Task 10 — 선체·실드 HUD

- 목적: 전투 중 현재/최대 선체와 실드를 좌측 패널에서 확인
- 수정 예상: `menus/ship_status_hud.gd`, `world.tscn`
- 완료: 두 자원이 색으로 구분되고, 함선 파괴 후에도 HUD가 죽은 노드를 참조하지 않음

## Task 4 — 스펙·테스트

- 목적: 문서 동기화 + 회귀 방지
- 수정 예상: `docs/spec/{player,components,scene-flow,combat,gaps}.md`, `tests/ship_facility_upgrade_test.gd`
- 완료: 스모크 테스트 PASS, 현황 스펙이 구현과 일치

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-01 | 초기 Task |
| 2026-08-01 | Task 8~10 추가 (선체·실드 개명 + 실드 게이트, 시설 오그먼트, 선체·실드 HUD) |
