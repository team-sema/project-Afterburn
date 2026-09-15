# 함선 모듈 · 동력로

tag: `hangar` (UI 표시명 **동력로**)

## 외형

![동력로](sprites/facility_hangar.svg)

동력로(hangar) tag 모듈이 공유하는 시설 아이콘. 비상 출력 장치도 같은 SVG를 쓴다.
- 스프라이트: `assets/svg/facilities/facility_hangar.svg`

| ID | 표시명 | Kind · 수치 |
|----|--------|-------------|
| `facility_hangar` | 과충전 반응로 | `PERIODIC_DAMAGE_BUFF` ×1.4 · 5초 · 주기 20초 |
| `facility_reactor_emergency` | 비상 출력 장치 | `HULL_HIT_DAMAGE_BUFF` ×1.3 · 5초 · CD 15초 (**선체 피격만**) |

상위: [함선 모듈](index.md)
