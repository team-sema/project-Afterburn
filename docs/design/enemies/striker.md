# Striker

## 외형

![Striker](sprites/enemy_striker.svg)

Drone보다 **가로로 넓은 다이아몬드**. 양옆으로 펼친 날개감이 있어 편대 핵으로 읽힌다. 같은 분홍 네온 팔레트.
- 스프라이트: `assets/svg/enemy_striker.svg`
- 틴트: 분홍 글로우 (베이스 `enemy.tscn` 상속)

## 의도

호위 편대의 **핵**. Drone 구름 뒤에 있어서, “어디부터 부술지”를 고르게 한다.
편대가 진입 이동을 마치면 풀리며 산개·돌진으로 판이 바뀐다. 핵 처치로 해제되는 동작은 현재 구현되어 있지 않다.

## 플레이어가 고민할 점

- 호위가 두꺼울 때 핵을 먼저 노릴지 판단하기
- 풀린 뒤 돌진 각을 피할지, 미리 깎아 둘지
- 산개한 Drone 잔당을 무시할지, 끝까지 청소할지

## 하지 않는 것

- 혼자 화면을 지배하는 탄막 (Caster / Sniper 몫)
- 자폭으로 공간을 지우는 압박 (Bomb 몫)
- “HP만 두꺼운 Drone” — 핵으로서 읽혀야 한다

## 편대·Encounter에서의 역할

Diamond 호위 편대의 꼭짓점·후방. 예전 단독 프리셋은 풀 밖에 둔다.


## 확정 규칙·수치


| 항목 | 값 |
|------|-----|
| 씬 | `enemies/moving_enemy.tscn` |
| HP | 60 |
| 점수 | 10 |
| 최소 Threat | 1 |
| 사격 | `EnemyShootComponent` 조준 산탄 |

## Threat 1 사격 (호위 편대)

| `fire_interval` | 볼리 | 발수 | 탄속 | `initial_delay` |
|---|---|---|---|---|
| 4.5 | 2 (`burst_interval` 0.15) | 5 (`spread` 15°) | 80 | 1.5 |

전역 일반 적 사격 안전선을 사용하므로 중심점이 플레이필드 높이의 70% 아래로 내려가면 발사하지 않는다.

## 조합에서 쓰이는 곳

| Encounter | 역할 |
|-----------|------|
| `striker_drone_diamond_5` | Diamond5 최후방(Slot0) · 해제 후 플레이어 돌진 |
| `striker_drone_diamond_13` | Diamond13 꼭짓점 · 동일 산개 규칙 |

레거시 `striker_single`은 풀 미등록.

→ [Encounter 카탈로그](../encounters/catalog.md) · [Diamond 5](../formations/diamond-5.md)


## 확인 필요

기존 의도는 “핵 처치 → 편대 해제”였으나 두 Diamond 프리셋은 SEQUENCE_FINISHED를 사용하고 FormationController의 멤버 이탈 처리는 해당 슬롯만 제거한다. 핵 처치 해제를 추가할지, 이동 완료 해제를 최종 의도로 유지할지는 미결정이다. 이번 문서 정리에서는 게임 규칙을 변경하지 않는다.

## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
