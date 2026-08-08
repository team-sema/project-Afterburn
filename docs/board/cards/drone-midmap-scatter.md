# 드론 중반 2배속 산개

## 목표

X9 / V3 / V5 / V7 / V9 / X5 드론 편대가 `TOP_RANDOM`으로 스폰된 뒤 맵 절반(y≈0.5)에 도달하면 편대를 해제하고, 진입 속도의 2배로 외향 산개한다.

## AC 요약

- midmap entry → SEQUENCE_FINISHED break
- scatter speed = 120 (entry 60의 2배)
- 산개 방향: 좌익→좌하, 우익→우하, 중앙→하방 (교차 방지)
- 스폰: TOP_RANDOM
- 대상: X9 / V3 / V5 / V7 / V9 / X5
- V9 레이아웃·프리셋 추가 (랩/테스트용, 풀 weight 없음)

## 구현

- 2026-08-08 `feature/drone-midmap-scatter` → main (검증 대기)
