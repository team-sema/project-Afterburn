# diamond-formation-sizes tasks

- [x] `diamond_formation.tscn` 간격 축소 (±32/±28) · 루트명 `DiamondFormation5`
- [x] `diamond_formation_13.tscn` (1-3-5-3-1, step 20)
- [x] `striker_drone_diamond_5.tres` / `_13.tres` · 구 `striker_drone_diamond.tres` 삭제
- [x] `main_encounter_pool.tres` 등록 (5→threat1, 13→threat2)
- [x] `formation_entry_third` + `individual_scatter_2_5` + `individual_striker_charge_2_5` · 패트롤 제거
- [x] `docs/spec/enemies.md` · 스모크 테스트 동기화

## AC 검증

1. Threat 1에 `_5`만, Threat 2+에 `_13` 포함.
2. 5기 스폰 멤버 5 · 13기 멤버 13.
3. 1/3 진입 후 SEQUENCE_FINISHED → Drone 외향 산개 · Striker 플레이어 돌진 · 이속 100(=40×2.5).
4. formation_layout / enemy_threat / weapon_test_lab / movement_sequence 스모크 PASS.
