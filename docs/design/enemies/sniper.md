# Sniper

## 외형

![Sniper](sprites/enemy_sniper.svg)

아래로 매우 긴 **창·바늘** 실루엣. 몸통은 가늘고 날개 폭이 좁아, 조준선과 함께 “저격수”로 읽힌다.
- 스프라이트: `assets/svg/enemy_sniper.svg`
- 틴트: 분홍 네온 (베이스 상속)

## 의도

**조준선으로 “지금 서 있는 자리”를 버리게** 만든다.
맞기 전에 그곳이 죽는 자리라는 걸 보여 주고, 움직이거나 끊게 한다. 앞에 Tanker 등이 있으면 “앞을 막은 채로 뒤를 노리는” 읽기가 생긴다.

## 플레이어가 고민할 점

- 조준이 모이는 타이밍에 자리를 비우기
- 앞을 가리는 가드·전방 실드 너머의 우선순위
- 가만히 서서 딜만 넣는 플레이를 끊기

## 하지 않는 것

- 경고 없는 고속 즉사탄 (선이 보여야 한다)
- 화면을 메우는 다연발 장판 (Caster 몫)
- 돌진 몸박 (Awl 몫)

## 편대·Encounter에서의 역할

가드 + Sniper 편대가 기본. 이미 탱커가 있으면 단독 보강으로 바뀔 수 있다 (구현).


## 확정 규칙·수치


| 항목 | 값 |
|------|-----|
| 씬 | `enemies/sniper_enemy.tscn` |
| HP | 95 |
| 점수 | 25 |
| 최소 Threat | 2+ (호위 Encounter) |

## 원거리 저격

- `sniper_entry_hold.tres`: `MoveToPositionStep`(y=48) → `HoldPositionMovementStep`
- `SniperAttackComponent`: AIMING(4.0s, 플레이어 추적 + 옅은 적색 이중선 cubic ease-out 수렴 → 0.18s 유지) → FIRING(900px/s + 5px 반동) → COOLDOWN(2.5s) 반복
- 조준선: 반각 14°→0.05°, 알파 0.01→0.36. 발사 순간 선 소실, 탄은 마지막 경로를 추적 없이 이동
- 재발사 시 재포지셔닝 없음. `EnemyShootComponent`는 `_enter_tree`에서 제거

## 조합

- 기본: `tanker_guard_sniper` — 전방 Tanker + 후방 Sniper. 편대 유지 중 **Sniper만** 사격
- 탱커가 이미 살아 있으면 `sniper_reinforcement` 단독으로 대체
- Tanker 실드 피격: Flash + Scale ×1.08 (Shake 없음). 본체 Scale ×1.1 · Shake 0.5

→ [Encounter 카탈로그](../encounters/catalog.md)


## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
