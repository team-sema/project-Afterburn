# HorizontalFormation

![Horizontal](sprites/layout_horizontal.svg)

| 항목 | 값 |
|------|-----|
| 씬 | `formations/layouts/horizontal_formation.tscn` |
| 슬롯 | 5 (가로 한 줄) |

## 슬롯

| Slot | id | 오프셋 (x, y) |
|------|-----|---------------|
| 0 | `left_outer` | (-48, 0) |
| 1 | `left_inner` | (-24, 0) |
| 2 | `center` | (0, 0) |
| 3 | `right_inner` | (24, 0) |
| 4 | `right_outer` | (48, 0) |

## 사용 Encounter

- `drone_formation` (`drone_straight_formation.tres`) — 대각 이동 sequence와 조합 · WAVE `straight`
