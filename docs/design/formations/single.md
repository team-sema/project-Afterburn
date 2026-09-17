# SingleFormation

![Single](sprites/layout_single.svg)

| 항목 | 값 |
|------|-----|
| 씬 | `formations/layouts/single_formation.tscn` |
| 슬롯 | 1 |

## 슬롯

| Slot | id | 오프셋 (x, y) |
|------|-----|---------------|
| 0 | `single` | (0, 0) |

즉시 해제(`SEQUENCE_FINISHED` 등) 후 개별 `MovementSequence`를 타는 Encounter에 쓴다.

## 사용 Encounter

- `caster_single`
- (대체) `sniper_reinforcement` 계열
- `threat_elite_single` / `threat_elite_awl` (엘리트 전용)
