# DiamondFormation5

![Diamond5](sprites/layout_diamond5.svg)

| 항목 | 값 |
|------|-----|
| 씬 | `formations/layouts/diamond_formation.tscn` |
| 슬롯 | 5 |
| 간격 | 좌우 ±32 · 상하 ±28 |

## 슬롯

| Slot | id | 오프셋 (x, y) |
|------|-----|---------------|
| 0 | `top` | (0, -28) |
| 1 | `left` | (-32, 0) |
| 2 | `center` | (0, 0) |
| 3 | `right` | (32, 0) |
| 4 | `bottom` | (0, 28) |

## 사용 Encounter

| Encounter | Slot0 / center | 나머지 |
|-----------|----------------|--------|
| `striker_drone_diamond_5` | Striker (`top`) | Drone ×4 |
| `bomb_drone_diamond` | Bomb (`center`) | Drone `top`/`left`/`right`/`bottom` |

멤버·이동은 [catalog](../encounters/catalog.md) 참고.
