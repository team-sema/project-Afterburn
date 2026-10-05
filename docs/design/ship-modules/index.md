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
| 동력로 | ![동력로](sprites/facility_hangar.svg) | 1 | [동력로](reactor.md) |
| 엔진 | ![엔진](sprites/facility_engine.svg) | 1 | [엔진](engine.md) |
| 선체 | ![선체](sprites/facility_hull.svg) | 1 | [선체](hull.md) |
| 레이더 | ![레이더](sprites/facility_radar.svg) | 2 | [레이더](radar.md) |
| 실드 | ![실드](sprites/facility_shield.svg) | 2 | [실드](shield.md) |

합계 **10종**. 아이콘은 흰 마스크 SVG를 시안 글로우로 칠해 쓴다. 상세의 **외형** 절에 미리보기가 있다.

모든 시설 모듈은 설치하면 바로 효과가 난다. 효과 없는 카드, 별도 키 입력으로 발동하는 카드, 쿨다운이 있는 카드는 두지 않는다. 그래서 반응 장갑(빈 카드)·비상 부스터(Shift 발동, 쿨다운 7초)·비상 출력 장치(쿨다운 15초)를 풀에서 뺐다. `ENGINE_BOOST`·`HULL_HIT_DAMAGE_BUFF` Kind와 `EngineBoostComponent`는 코드에 남아 있지만 이 Kind를 쓰는 카드는 없다.

## 등급

상시 수치 모듈은 실버, 발동·조건 효과 모듈은 골드다. 등급 규칙은 [오그먼트 — 등급](../augments.md#등급).

| 등급 | 모듈 |
|------|------|
| 실버 (7) | 집속 조준기 · 대형 표적 해석기 · 사격 통제 장치 · 추력 편향기 · 광역 탐지기 · 전투 데이터 분석기 · 실드 축전기 |
| 골드 (3) | 과충전 반응로 · 충격 분산 골격 · 급속 재충전기 |

## 완료 조건·검증

- 시설 모듈만 범용 슬롯에 들어가고 무기 Kind는 들어가지 않는다.
- 오퍼 풀의 시설 모듈은 10종이며, 효과 없는 카드·키 입력 발동 카드·쿨다운 카드가 없다 (`tests/weapon_augment_acquisition_test.gd`).
- 부위별 문서의 ID·수치가 `resources/player_augments/` 카드와 일치한다.
