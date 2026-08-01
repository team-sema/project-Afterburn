# 함선 시설 강화 · 오른쪽 함선 UI

## 목표

- 시설 6종으로 **공통 스탯만** 강화 (무기실=주무기 공격력, 격납고=보조 최대 탄약, 엔진=이동속도, 선체=최대 내구도, 레이더=수집 반경, 실드=최대 실드)
- 무기 고유 성능·공격 방식은 오그먼트 담당 — 시설 코드에 무기 id 분기 없음
- 시설 레벨은 **오그먼트 선택으로만** 오르고, 우측 STATUS UI는 읽기 전용 표시

## AC

- 6시설 표시 + 레벨 변경 즉시 UI 갱신, 클릭·마우스 오버로 현재/다음 레벨 효과 확인
- 시설 강화는 오그먼트 선택으로만 가능하고, 최대 레벨 시설 카드는 선택지에서 제외
- 무기실 보너스가 주무기 교체 후에도 유지, 보조·고유 성능 무영향
- 격납고가 최대 탄약에 반영, 탄약 0 → 기존대로 슬롯 제거
- 실드 ≥ 1이면 초과 피해가 선체로 넘어가지 않고, 실드 0일 때만 선체가 깎임
- 전투 화면에서 현재/최대 선체·실드 확인 가능
- 시설 수치가 `resources/facilities/definitions/*.tres` 한곳에만 존재

## 미확정

- 밸런스 수치·상한은 플레이스홀더 (`level_values` 표만 고치면 됨). 기본 최대 선체가 1이라 선체·실드 가산도 1 단위
- 실드 리필 수단 없음 — `restore_shield()` 인터페이스만 제공
- 궤도 방벽은 탄약 카운터가 없어 격납고 보너스 미적용 (환산 규칙 미정)
- 오퍼 풀이 11장으로 늘어 카드별 등장 확률이 낮아짐 (가중치 도입 여부 미정)

## 구현

- `resources/facilities/*`, `ship_facility_registry.gd`, `components/ship_facility_applier.gd`
- `components/shield_component.gd`, `components/hurt_component.gd` (실드 게이트)
- `resources/player_augments/facilities/*`, `augment_offer_controller.gd`
- `menus/ship_panel.*`, `menus/ship_facility_module.*`, `menus/ship_facility_links.gd`, `menus/ship_diagram.tscn`, `menus/ship_status_hud.gd`
- 2026-08-01 `feature/ship-facility-upgrades` 구현 중
- 2026-08-01 목업 기준으로 UI 정리 (시설 아이콘, 함선 중심 배치 + 배선, 상세 박스, 무기 HUD 박스화)
- 2026-08-01 레이더·코어 추가로 시설 6종, 세 패널 모서리 브래킷(`NeonCornerFrame`)
- 2026-08-01 장갑→선체, 코어→실드(실드 게이트), 시설 오그먼트 6종, 좌측 선체·실드 HUD
- 2026-08-01 `feature/ship-facility-upgrades` → main (검증 대기)
