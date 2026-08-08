# 적 편대·자폭 이동

## 목표

- Drone: 5마리 고정 편대 + 얕은 대각 하강(측면 ping-pong)
- Striker: 직하강 → 중앙 정지 → 좌우 패트롤
- Awl 자폭: 하강 → 조준 → 락온 돌진 (투사체 없음)

## 구현

- Drone/Awl은 `EncounterPreset` + `FormationLayout` + 단일 `FormationController`; Striker는 `striker_entry_patrol.tres` + 개별 `MovementController`
- 편대 해제 시 각 Enemy가 멤버별 context를 받아 개별 MovementSequence로 전환
- `enemy_awl.svg`, `kamikaze_enemy.tscn`
- 2026-07-31 `feature/striker-zigzag-formation` → main (검증 대기)
