# STATUS 무기 수치 표시

## 목표

포커스한 무기의 실효 전투 수치(피해·간격 등)를 STATUS 하단에 표시.

## AC

- [x] 무기 설명 아래 수치 한 줄
- [x] 레벨·시설 배율 반영
- [x] 특성 호버 시 수치 숨김

## 구현

- `WeaponSystem.get_status_stat_line()`
- `WeaponLoadoutHud` 푸터
- 2026-08-05 `feature/weapon-status-stats` → main (검증 대기)
