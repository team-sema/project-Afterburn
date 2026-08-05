# Feature: 시작 실드 1

## 목적

런 시작 시 플레이어가 실드 1(버퍼 HP)로 시작해 첫 피해를 실드에서 받을 수 있게 한다.

## 규칙

1. `ShieldComponent.base_max_shield` 기본값 **1** (현재도 최대치로 시작).
2. 실드 축전기 모듈은 그 위에 최대 +1씩 (시설 곡선).

## AC

- [x] 시작 최대·현재 실드 1
- [x] `docs/spec/player.md` · `components.md` 반영
- [x] 시설 테스트: 모듈 1개 → 최대 2

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-06 | base_max_shield 0 → 1 |
