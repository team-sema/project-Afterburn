# Feature: 시설이 효과 담당 (스탯 모듈 제거)

## 목적

함선 부위 효과는 **시설 효과 모듈만** 담당한다. 이속·피해 등을 스탯 모듈과 시설이 이중으로 곱하던 경로를 제거한다.

## 규칙

1. 플레이어 오퍼 풀에서 `STAT_MULTIPLIER` 3종을 삭제한다.
2. 부위 슬롯 설치 Kind는 `FACILITY_EFFECT`만.
3. 엔진 이속·무기실 피해 등은 `ShipFacilityDefinition.module_count_values`만 사용한다.
4. `docs/spec/augments.md` · `player.md` 풀·규칙을 코드와 동기화한다.

## AC

- [x] Gameplay 풀에 스탯 모듈 없음 (22종)
- [x] 스펙·시스템 문서 시설 전담으로 갱신
- [x] 시설 슬롯 스모크가 시설 모듈만 사용

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-05 | 스탯 3종 삭제 · 스펙 정합 |
