# Feature: 무기 수치는 스펙만

## 목적

무기 전투 기본값은 `docs/spec/player.md`에서 트래킹한다. STATUS HUD에는 이름·레벨·설명·특성만 두고 **수치 줄을 표시하지 않는다**.

## 규칙

1. `WeaponSystem.get_status_stat_line` / `get_weapon_stat_summary` / STATUS 푸터 수치 줄을 제거한다.
2. 기본 전투 수치는 `docs/spec/player.md` 표에 씬 익스포트 기준으로 적는다.
3. 인게임 디테일 푸터는 무기/특성 **설명만** 보여 준다.

## AC

- [x] STATUS 푸터에 피해·간격 등 전투 수치 없음
- [x] `docs/spec/player.md`에 7종 기본 수치 표
- [x] 관련 스모크 통과

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-05 | 인게임 수치 표시 철회 · 스펙 표로 이전 |
