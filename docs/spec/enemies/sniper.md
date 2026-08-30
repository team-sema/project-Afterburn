# Sniper

| 항목 | 값 |
|------|-----|
| 씬 | `enemies/sniper_enemy.tscn` |
| HP | 95 |
| 점수 | 25 |
| 최소 Threat | 2+ (호위 Encounter) |

## 원거리 저격

- `sniper_entry_hold.tres`: `MoveToPositionStep`(y=48) → `HoldPositionMovementStep`
- `SniperAttackComponent`: AIMING(4.0s, 플레이어 추적 + 옅은 적색 이중선 cubic ease-out 수렴 → 0.18s 유지) → FIRING(900px/s + 5px 반동) → COOLDOWN(2.5s) 반복
- 조준선: 반각 14°→0.05°, 알파 0.01→0.36. 발사 순간 선 소실, 탄은 마지막 경로를 추적 없이 이동
- 재발사 시 재포지셔닝 없음. `EnemyShootComponent`는 `_enter_tree`에서 제거

## 조합

- 기본: `tanker_guard_sniper` — 전방 Tanker + 후방 Sniper. 편대 유지 중 **Sniper만** 사격
- 탱커가 이미 살아 있으면 `sniper_reinforcement` 단독으로 대체
- Tanker 실드 피격: Flash + Scale ×1.08 (Shake 없음). 본체 Scale ×1.1 · Shake 0.5

→ [Encounter 카탈로그](#encounters/catalog)
