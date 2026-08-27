# Bomb 편대 호위

## 목표

초기 Tanker 수직 호위안. 현재 `bomb-diamond-escort` 작업에서 Drone 다이아몬드 중앙 Bomb Encounter로 교체한다.

## AC

- Pool에 bomb_single · tanker_bomb_vertical · tanker_bomb_horizontal 없음
- Tanker 호위안은 `bomb_drone_diamond`로 교체
- Bomb 호밍 접근 · 폭발 아군(적) 범위 처치는 유지

## 구현

- 2026-08-09 `feature/bomb-formation-escorts` → main (검증 대기)
- 2026-08-09 보드 검증: review → done
- 2026-08-21 후속 `feature/bomb-diamond-escort`에서 Drone 다이아몬드 호위로 교체
