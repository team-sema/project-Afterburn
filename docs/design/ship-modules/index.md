# 함선 모듈

함선 범용 슬롯에 들어가는 **시설 효과 모듈**(`FACILITY_EFFECT`) 목록이다. 무기 전용 강화는 [무기 모듈](../weapon-modules/index.md)을 본다.

## 기획 의도

시설 tag(무기실·동력로·엔진·선체·레이더·실드)로 빌드 방향을 고르고, 동일 Kind는 배율 곱·가산 합으로 중첩한다.

## 확정된 현재 동작

- Kind: `FACILITY_EFFECT` only · 범용 슬롯(시작 5 · 최대 15)에만 설치
- primary tag `hangar` UI 표시명 = **동력로** (키·아이콘은 `hangar` 유지)
- 부위별 모듈은 **같은 시설 SVG 아이콘**을 공유한다 (`assets/facilities/`)
- 적용: `ShipFacilityApplier` · `ShipCombatBuffController` · `EngineBoostComponent` · `HurtComponent`
- 오퍼·슬롯 규칙은 [오그먼트](../augments.md)

## 부위별 문서

| 부위 | 아이콘 | 모듈 수 | 문서 |
|------|--------|---------|------|
| 무기실 | ![무기실](sprites/facility_weapon_room.svg) | 3 | [무기실](weapon-room.md) |
| 동력로 | ![동력로](sprites/facility_hangar.svg) | 2 | [동력로](reactor.md) |
| 엔진 | ![엔진](sprites/facility_engine.svg) | 2 | [엔진](engine.md) |
| 선체 | ![선체](sprites/facility_hull.svg) | 2 | [선체](hull.md) |
| 레이더 | ![레이더](sprites/facility_radar.svg) | 2 | [레이더](radar.md) |
| 실드 | ![실드](sprites/facility_shield.svg) | 2 | [실드](shield.md) |

합계 **13종**. 아이콘은 흰 마스크 SVG를 시안 글로우로 칠해 쓴다. 상세의 **외형** 절에 미리보기가 있다.

## 완료 조건·검증

- 시설 모듈만 범용 슬롯에 들어가고 무기 Kind는 들어가지 않는다.
- 부위별 문서의 ID·수치가 `resources/player_augments/` 카드와 일치한다.
