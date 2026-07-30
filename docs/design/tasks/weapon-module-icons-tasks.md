# Feature tasks: 무기 육각 모듈 아이콘

## Done

- [x] `assets/svg/weapons/` 무기 아이콘 7종 (흰색 마스크 · 64×64)
- [x] `WeaponDefinition.icon` 7개 정의에 연결
- [x] `HexModuleFrame` 아이콘 슬롯 + 제목/아이콘/수치 3단 레이아웃
- [x] `WeaponLoadoutHud` 이름 제거, 레벨·잔탄만 텍스트로 유지
- [x] `PlayerWeaponLoadout.get_weapon_icon` (보유 주무기 행용)
- [x] 아이콘 누락 시 이름 폴백
- [x] `tests/weapon_module_icons_test.gd` 스모크 테스트

## Verify

- [ ] 플레이 중 메인/예비 Z 스왑 시 아이콘이 따라 바뀐다
- [ ] 보조 소진 → 슬롯 비면 아이콘이 사라진다
- [ ] 보조 리필 후 잔탄 수치가 갱신된다
- [ ] 36px 보유 주무기 행에서 무기 구분이 되는지 눈으로 확인
- [ ] 필드 픽업·보조 교체 오버레이는 여전히 이름 표시 (이번 범위 밖)

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-30 | 초기 Task 작성 |
