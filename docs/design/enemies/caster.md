# Caster

## 의도

상단에 붙어 **탄막 장판**으로 아래 공간을 좁힌다.
회피 동선을 “아무 데나”가 아니라, **비어 있는 통로**를 찾게 만든다. Threat가 오른 뒤에 나와, 초반과는 다른 리듬을 연다.

## 플레이어가 고민할 점

- 링·탄막 패턴 읽기
- 상단 화력을 먼저 넣을지, 아래 잡몹을 먼저 정리할지
- 떠 있는 위치를 기준으로 세로 공간 관리하기

## 하지 않는 것

- 돌진·자폭형 근접 압박 (Awl / Bomb 몫)
- 측면을 고속으로 스치는 패스 (Interceptor 몫)
- “그냥 총알 많이 쏘는 잡몹” — 장판으로 공간을 조이는 게 핵심

## 편대·Encounter에서의 역할

혼자 떠 있거나, X9 중심에서 Drone이 공전하는 연출형으로 쓴다.


## 확정 규칙·수치


| 항목 | 값 |
|------|-----|
| 씬 | `enemies/shooting_enemy.tscn` |
| HP | 110 |
| 점수 | 25 |
| 최소 Threat | 3 |
| 비주얼 | `enemy_caster.svg` |

## 상단 체공 · 원형 탄막

- `caster_entry_patrol.tres`: `MoveToPositionStep`으로 y=56 진입 후 `HorizontalPatrolMovementStep`
- `RadialBarrageShootComponent`: 주기마다 링 5회 × 20발 (링마다 소각 회전), `base_enemy_projectile`
- 레거시 상태머신 / `EnemyShootComponent`는 `_enter_tree`에서 제거

## 조합

| Encounter | 역할 |
|-----------|------|
| `caster_single` | [Single](../formations/single.md) 1슬롯 → 즉시 해제 → 개별 패트롤 |
| `x9_caster_drone_orbit` | [X9](../formations/x9.md) 중심 Caster + Drone 공전 |

→ [Encounter 카탈로그](../encounters/catalog.md)


## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.

## 변경 이력

- 2026-09-13: 기획 의도와 구현 규칙을 통합.


| 날짜 | 변경 |
|------|------|
| 2026-08-30 | 한국어 문장 정리 |
| 2026-08-30 | 기획 문서 |
