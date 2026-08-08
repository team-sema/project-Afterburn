# Bomb 편대 호위

## 목표

단독 `bomb_single`을 제거하고, Bomb를 **수직 탱커 편대**로만 등장시킨다.

## 동작

| Encounter | 레이아웃 | 멤버 | 이동 | break | difficulty | min_threat |
|---|---|---|---|---|---:|---:|
| `tanker_bomb_vertical` | Vertical | Tanker front + Bomb center | 플레이어 호밍 하강 22px/s | NEVER | 9 | 2 |

- `bomb_drone_diamond` · `tanker_bomb_horizontal` · `bomb_single` 삭제.
- `tanker_bomb_vertical`은 플레이어를 향해 천천히 접근. Bomb가 `trigger_radius`(60) 이내면 기폭 무장 시작(편대 정지·Bomb detach).
- Bomb 폭발 시 반경 내 다른 적 유닛도 즉시 제거(호위 Tanker 포함).
- `tanker_guard_sniper` · `striker_drone_diamond_5/13` 산개 편대는 유지.
- `enemy_bomb_fast_fuse.target_spawn_id`는 비움 (모든 Bomb에 ARMING_RATE 적용).

## AC

1. Pool에 `bomb_single` · `bomb_drone_diamond` · `tanker_bomb_horizontal` 없음.
2. Threat 2+에 `tanker_bomb_vertical`만 Bomb Encounter.
3. 스펙·스모크 동기화.

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-09 | 초안 · single 제거 · 탱커/다이아몬드 Bomb 편대 |
| 2026-08-09 | horizontal 삭제 · vertical 플레이어 접근 호밍 |
| 2026-08-09 | 폭발 시 범위 내 적 동시 처치 |
| 2026-08-09 | `bomb_drone_diamond` 삭제 |
