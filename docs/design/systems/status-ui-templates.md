# Feature: STATUS HUD UI 템플릿 플레이스홀더

## 목적

런타임에만 만들던 무기 헥스 UI를 에디터에서 보이는 템플릿으로 두어, 사람이 크기·간격을 씬에서 조절할 수 있게 한다.

## 규칙

1. `menus/weapon_core_cluster.tscn` — Core + TraitHexTemplate + TraitCaptionTemplate
2. `world.tscn` `WeaponLoadoutHud/HudTemplates` — `%BaySlotTemplate`, `%ModuleHexTemplate`
3. `%SelectedWeaponHex` — 선택 무기 프리뷰 (씬 자식, TextureRect는 숨김)
4. 런타임은 템플릿 `duplicate()` 후 데이터 바인딩. 크기 기준은 템플릿 `custom_minimum_size`
5. 함선 시설·증강 오버레이 버튼은 이미 씬 고정이라 범위 밖

## AC

- [x] 에디터에서 Bay/Module/Selected 헥스 템플릿이 보임
- [x] 런타임 슬롯·모듈이 템플릿 크기를 따름
- [x] 기존 호버 포커스·모듈 설명 동작 유지
- [x] weapon_status_focus_detail 스모크 PASS

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-05 | 초기: STATUS 무기 HUD 템플릿화 |
