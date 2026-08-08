# Sniper 저격 적기

## 목표

원거리 고정 포지션에서 플레이어를 지속 추적하고, 수렴하는 이중 조준선으로 경로를 예고한 뒤 고속 탄환을 발사하는 적.

## AC 요약

- POSITIONING 1회 → AIMING(4s 추적+이중 조준선, 0.18s 완전 조준) → FIRING → COOLDOWN(2.5s) 반복
- 조준선은 cubic ease-out으로 수렴하며 옅게 시작해 중앙에서 진해짐
- 발사 경로로 900px/s 고속 탄환을 발사하고 기체 비주얼에 짧은 반동 적용

## 구현

- 2026-08-09 `feature/sniper-attack-rework` → main (검증 대기)
- 2026-08-08 `feature/sniper-enemy` → main (검증 대기)
