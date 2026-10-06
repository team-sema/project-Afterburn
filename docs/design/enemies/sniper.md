# Sniper

## 외형

![Sniper](sprites/enemy_sniper.svg)

아래로 매우 긴 **창·바늘** 실루엣. 몸통은 가늘고 날개 폭이 좁아, 조준선과 함께 “저격수”로 읽힌다.
- 스프라이트: `assets/enemies/enemy_sniper.svg`
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
- `SniperAttackComponent`: AIMING(2.5s, 플레이어 추적 + 옅은 적색 이중선 cubic ease-out 수렴) → LOCKED(락온 0.75s, `lock_on_duration`) → FIRING(900px/s + 5px 반동) → COOLDOWN(2.5s) 반복
- 조준선: 반각 14°→0.05°, 알파 0.01→0.36. 완전히 수렴하면 **락온**한다. 선이 플레이어를 더 따라가지 않고 그 자리에 멈추며, 알파 0.62·두께 1px로 밝아져 멈춘 것이 보인다. 0.75초 뒤 그 멈춘 선으로 쏜다. 발사 순간 선 소실, 탄은 그 경로를 추적 없이 이동
- 락온은 멈춰 있던 플레이어에게 피할 틈을 준다. 선이 멈추는 것을 보고 옆으로 비키면 피한다. ACTION_RATE는 락온 시간에도 적용된다.
- 재발사 시 재포지셔닝 없음. `EnemyShootComponent`는 `_enter_tree`에서 제거
- 단발 생성은 `SniperBarrageShot` 어댑터를 사용한다. 기존 SniperBullet의 선형 외형·900px/s 기준 3×30px 판정·사거리·피해량·finished 신호를 보존한다. 조준선·반동·타이밍은 SniperAttackComponent가 소유한다. 어댑터 연결이며 일반 FoundationBullet 몸체로 바꾸지 않는다.
- 반동은 ShakeComponent의 지속 위치 오프셋에 적용하고 피격 흔들림과 합산한다. 흔들림 갱신이 반동 위치를 원점으로 덮어쓰지 않는다.
- 편대 멤버로 스폰되면 그 자리에서 바로 조준을 시작한다(`sniper_reinforcement`는 1칸 편대라 진입하면서 첫 조준). 조준 중 편대 해제로 부모가 바뀌어도 조준선은 계속 보인다(`_enter_tree`에서 복구).

## 조합

- 기본: `tanker_guard_sniper` — 전방 Tanker + 후방 Sniper. 편대 유지 중 **Sniper만** 사격
- 탱커가 이미 살아 있으면 `sniper_reinforcement` 단독으로 대체
- Tanker 실드 피격: Flash + Scale ×1.08 (Shake 없음). 본체 Scale ×1.1 · Shake 0.5

→ [Encounter 카탈로그](../encounters/catalog.md)

## 진화형 (`enemies/evolved/sniper_evolved.tscn`)

적 증강 [진화: 속사 저격수](../augments.md#진화-증강)를 고르면 이후 Sniper가 이 씬으로 스폰된다. 조준(2.5초)·수렴·쿨다운은 원본과 같다.

- 락온이 **0.25초**(`lock_on_duration`)로 짧다. 선이 멈춰 밝아지는 것은 같지만, 보고 비킬 시간이 0.75초에서 0.25초로 줄어든다.
- 수렴 막바지에 미리 움직이고 있어야 피하기 쉽다.

## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
- `sniper_reinforcement`로 나온 Sniper도 첫 조준선이 편대 해제 뒤까지 보인다.
- 원본은 2.5초 조준·수렴 뒤 선이 멈추고 밝아진 채 0.75초 락온한 다음, 멈춘 선으로 쏜다. 락온 동안 플레이어가 움직여도 선은 따라가지 않는다.
- 진화형은 같은 조준 뒤 락온 0.25초 만에 쏜다.
