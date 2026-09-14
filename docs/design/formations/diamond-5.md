# DiamondFormation5

| 항목 | 값 |
|------|-----|
| 씬 | `formations/layouts/diamond_formation.tscn` |
| 슬롯 | 5 |
| 간격 (Striker 호위 기준) | 좌우 ±32 · 상하 ±28 |

## 슬롯

| Slot | 이름 | 위치 요지 |
|------|------|-----------|
| 0 | `top` | 화면 상단·최후방 |
| 1 | `left` | 좌 |
| 2 | `center` | 중앙 |
| 3 | `right` | 우 |
| 4 | `bottom` | 하단 팁 |

## 사용 Encounter

| Encounter | Slot0 / center | 나머지 |
|-----------|----------------|--------|
| `striker_drone_diamond_5` | Striker (`top`) | Drone ×4 |
| `bomb_drone_diamond` | Bomb (`center`) | Drone `top`/`left`/`right`/`bottom` |

멤버·이동은 [catalog](../encounters/catalog.md) 참고.
