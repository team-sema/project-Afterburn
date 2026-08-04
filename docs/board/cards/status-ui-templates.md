# STATUS HUD UI 템플릿

## 목표

무기 슬롯·모듈·선택 헥스를 씬 템플릿으로 두어 에디터에서 크기 조절.

## AC

- [x] 에디터 템플릿으로 Bay/Module/Selected 헥스 크기 조절
- [x] 런타임 `duplicate()` 바인딩
- [x] 기존 호버·모듈 설명 유지

## 구현

- `menus/weapon_core_cluster.tscn`
- `world.tscn` `%HudTemplates` / `%SelectedWeaponHex`
- 2026-08-05 `feature/weapon-status-hover` → main (검증 대기)
