# tanker-hit-feedback tasks

- [x] `FlashComponent.flash_root`로 다중 레이어 플래시
- [x] Tanker 실드 Scale + Shake + full flash
- [x] 쉐이크 과다 → amount 1.25 / 0.25s로 완화
- [x] 쉐이크 재완화 → 0.45 / 0.15s · Tanker 사격 제거
- [x] 실드 쉐이크 제거 · 스케일 1.08로 축소 (과한 모션 원인 수정)

## AC 검증

1. tanker_enemy_smoke_test PASS (shake/flash asserts)
2. 플레이에서 실드 피격이 Drone 피격과 비슷한 펀치감
