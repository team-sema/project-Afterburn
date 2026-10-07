# 함선 모듈 · 선체

tag: `hull`

## 외형

![선체](sprites/facility_hull.svg)

선체 tag 모듈이 공유하는 시설 아이콘.
- 스프라이트: `assets/facilities/facility_hull.svg`

| ID | 표시명 | Kind · 수치 |
|----|--------|-------------|
| `facility_hull_iframe` | 충격 분산 골격 | 선체 피격 무적시간 +1.0초 |
| `facility_hull_hit_point` | 압축 코어 | 피격점 반경 −1px (`HIT_POINT_RADIUS_ADD` 합산 · 하한 2px) |

선체 HP는 항상 1이며 전투 HUD에 표시하지 않는다.

압축 코어는 판정과 피격점 표시를 함께 줄인다. 적탄 반경(기본 3px)은 그대로라 실제 피격 거리는 6px → 5px다. 같은 카드를 겹쳐도 반경은 2px 아래로 내려가지 않는다. 규칙 정본은 [플레이어 — 생존](../player.md#생존).

상위: [함선 모듈](index.md)
