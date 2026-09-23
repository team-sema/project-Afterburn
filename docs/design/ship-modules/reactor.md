# 함선 모듈 · 동력로

tag: `hangar` (UI 표시명 **동력로**)

## 외형

![동력로](sprites/facility_hangar.svg)

동력로(hangar) tag 모듈이 공유하는 시설 아이콘. 비상 출력 장치도 같은 SVG를 쓴다.
- 스프라이트: `assets/facilities/facility_hangar.svg`

| ID | 표시명 | Kind · 수치 |
|----|--------|-------------|
| `facility_hangar` | 과충전 반응로 | `PERIODIC_DAMAGE_BUFF` ×1.4 · 5초 · 주기 20초 |
| `facility_reactor_emergency` | 비상 출력 장치 | `HULL_HIT_DAMAGE_BUFF` ×1.3 · 5초 · CD 15초 (**선체 피격만**) |

## 과충전 연출

- 과충전 활성 중 플레이어 탄·레이저·궤도 방벽은 `OverchargeVisualComponent`로 붉은 틴트를 켠다.
- 탄환 피해 배율은 **발사 시점 스냅샷**을 쓴다. 비행 중 과충전이 끝나도 이미 나간 탄의 피해·틴트는 유지된다.
- 레이저·궤도 방벽처럼 지속형 무기는 버프 on/off에 맞춰 틴트를 실시간으로 바꾼다.

상위: [함선 모듈](index.md)
