# Awl / Kamikaze

| 항목 | 값 |
|------|-----|
| 씬 | `enemies/kamikaze_enemy.tscn` |
| HP | 80 |
| 점수 | 15 |
| 최소 Threat | 1 |
| 투사체 | 없음 |

## 행동

- 스폰: `awl_charge_formation`가 [V3](#formations/v3) 슬롯 3개로 하강 구간만 편대 유지
- **하강 완료 순간** V에서 분리 → 각자 3초 조준(차징) → 플레이어 락온 방향으로 독립 돌진

→ [Encounter `awl_formation`](#encounters/catalog)
