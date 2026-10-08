# Bomb

## 외형

![Bomb](sprites/enemy_bomb.svg)

**원형 본체** 위에 짧은 사각형 신관·깃털 팁이 달린 폭탄형. 다른 전투기형과 달리 둥글어 근접 폭발 위협으로 바로 구분된다.
- 스프라이트: `assets/enemies/enemy_bomb.svg`
- 틴트: 분홍 네온 (베이스 상속). 기폭 시 붉은 범위 프리뷰 링이 추가로 보인다.

엘리트는 별도 [Elite Bomb](../elites/elite-bomb.md) 문서에서 관리한다.

## 의도


**가까이 가면 대가를 치르는** 적.
없애기 전에 “얼마나 붙어도 되는지”를 고민하게 만드는 **공간 압박**. 다가가면 멈추고 점멸한 뒤 폭발한다. 욕심내면 맞는다.

기본형은 위에서 **곧게 떨어지는 장애물**이다. 후반에는 [Courier](courier.md)가 같은 Bomb를 플레이어 앞에 **정지형**으로 떨어뜨려, 폭탄의 위치 자체를 플레이어의 사격 판단으로 만든다.

## 플레이어가 고민할 점

- 사거리와 위치 관리 (들이받지 않기)
- 떨어지는 두 Bomb 사이 통로로 지나갈지, 하나를 깎아 길을 낼지
- 폭발 범위(자신·주변 적)를 읽고 위험을 감수할지

## 하지 않는 것

- 원거리 탄막이 주력인 적 (Caster / Sniper 몫)
- 혼자 화면을 메우는 잡몹 웨이브 (한 번에 2기까지)
- 플레이어를 쫓아오는 이동 (기본형은 직선 하강, 정지형은 제자리)
- 예고 없이 즉사시키는 근접 (점멸·프리뷰로 읽을 시간을 준다)

## 편대·Encounter에서의 역할

- **기본형:** `bomb_pair` — 좌우 160px 간격의 Bomb 2기가 곧게 떨어진다. 두 신관 반경(60px) 사이에 폭 40px 통로가 남는다.
- **정지형:** [Courier](courier.md)가 투하한다. 같은 씬이며 이동과 대기 기폭만 다르다(아래 「정지형」).


## 확정 규칙·수치


| 항목 | 값 |
|------|-----|
| 씬 | `enemies/bomb_enemy.tscn` |
| HP | 160 |
| 점수 | 20 |
| 최소 Threat | 1 |
| 비주얼 | `enemy_bomb.svg` |
| 투사체 | 없음 |
| 이동 (기본형) | `bomb_straight_down.tres` — 아래로 **40px/s** 직선. DespawnArea 밖에서 정리(보상 없음) |

## 근접 자폭 (`BombProximityFuseComponent`)

- 플레이어가 `trigger_radius`(60) 안이면 정지 → **3초간 빨간 점멸 3회** → 자폭
- 편대 소속이면 기폭 시작 시 편대 중심 이동을 멈추고 Bomb를 detach한 뒤 무장
- 신관 무장과 적색 점멸이 시작되면 반투명 범위 프리뷰 표시
- 점멸 대기 중 Bomb가 처치·이탈 등으로 씬 트리에서 빠지면 신관 코루틴을 중단한다 (자폭하지 않음)
- 무장 중 detach된 Bomb는 편대가 준 개별 이동을 바로 멈추고 제자리에서 점멸한다
- 폭발 판정·VFX 최대 링·범위 프리뷰 반경은 모두 `base_explosion_radius(40) * 1.5 = 60px`
- `blast_damage` **1** (플레이어 피격은 이벤트당 항상 1)
- 폭발 반경 안의 **다른 적**은 hurtbox 겹침 시 즉시 처치(실드·HP 무시, 본인 제외). 점수·XP는 일반 `no_health` 경로
- `고속 기폭 장치` 적 증강 활성 시 무장 시간 `3.0초 / 1.5 = 2.0초` (`target_spawn_id` 없음 → 모든 Bomb)
- `arm_on_ready`가 켜져 있으면 거리와 관계없이 스폰 즉시 무장한다(점멸·자폭 규칙 동일). 기본형은 꺼져 있다

## 정지형 (Courier 투하)

- [Courier](courier.md)가 플레이어 옆을 스치는 순간 또는 격추되는 순간 그 자리에 스폰된다. 씬은 `bomb_enemy.tscn`을 적 증강 레지스트리로 해석한 것이라 진화형·증강이 그대로 적용된다
- 이동: `bomb_mine_hold.tres` — 제자리에 머문다
- **즉시 점화**(`arm_on_ready`): 떨어지는 순간 무장해 3초 점멸 뒤 자폭한다. 플레이어가 반경 안이면 비켜야 하고, 하단을 오래 막지 않는다
- HP·점수·폭발 규칙은 기본형과 같다

## 레거시 `bomb_drone_diamond`의 편대 해제 (`ANCHOR_LOST`)

풀·구절에서는 빠졌지만 프리셋은 남아 있다. `bomb_drone_diamond`는 Bomb 슬롯(Slot0 `top`)을 편대 앵커(`formation_anchor_slot_index`)로 둔다. 편대 호밍(`bomb_drone_approach`)에는 시간 제한이 없으므로, Bomb가 사라지면 반드시 편대를 해제한다.

- Bomb가 씬 트리에서 빠지는 순간(무장 전 격추·점멸 중 격추·자폭·화면 밖 해제) 남은 Drone을 전부 해제한다
- 무장 시작 시의 detach는 앵커 상실이 아니다. 점멸 동안 호위는 멈춘 편대 자리를 지킨다 (폭발 범위에 함께 걸리는 위험 유지)
- 해제된 Drone은 `individual_scatter`(슬롯 바깥 방향 100px/s 직선)로 흩어져 화면 밖에서 정리된다. 다시 플레이어를 호밍하지 않는다
- 자폭 시 호위 슬롯은 모두 폭발 반경(60px) 안이라 보통 함께 처치되고, 살아남은 Drone만 위 규칙으로 해제된다

## 조합

- 풀 등록: `bomb_pair` (Threat 2+) — [BombPair](../formations/bomb-pair.md) 즉시 해제 → 각자 직선 하강
- 구절 `B` 공간의 교재 A/B가 `bomb_pair`를 쓴다 — [런 페이싱](../run-pacing.md#구절-작곡-현재-기본-시퀀스)
- 정지형은 `courier_single` (Threat 3+)이 낸다 — [Courier](courier.md)
- 레거시 `bomb_drone_diamond`·`tanker_bomb_*`는 풀 미등록. `bomb_single` 프리셋 파일은 현재 존재하지 않는다

→ [Encounter 카탈로그](../encounters/catalog.md)

## 진화형 (`enemies/evolved/bomb_evolved.tscn`)

적 증강 [진화: 산탄 폭뢰](../augments.md#진화-증강)를 고르면 이후 Bomb가 이 씬으로 스폰된다. 근접 신관·폭발 규칙은 원본과 같다.

- 신관이 끝까지 타서 **자폭할 때만**, 폭발 지점에서 `round_straight_shot` **12발**을 **75px/s** 원형으로 뿌린다(`detonation_ring_count`).
- 무장 전·점멸 중에 처치하면 링은 나오지 않는다. 먼저 잡을 이유가 더 커진다.
- `고속 기폭 장치`는 진화형에도 적용된다.
- Courier가 떨어뜨리는 정지형도 진화 후에는 진화형으로 스폰된다.

## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
- 진화형은 자폭할 때만 탄 12발 링을 뿌리고, 먼저 처치되면 뿌리지 않는다.
- `bomb_courier_test.gd`: 기본형은 40px/s로 곧게 떨어지고, `bomb_pair`는 즉시 해제되어 두 Bomb가 160px 간격으로 각자 떨어진다. 정지형은 제자리에 머물며 스폰 즉시 점화된다.
- `bomb_drone_diamond_core_loss_test.gd`: 무장 전/점멸 중 Bomb 격추 시 호위 Drone이 편대에서 풀려 호밍·정지 없이 흩어지고, 무장 중에는 호위가 편대를 유지하며, 자폭 뒤 편대에 묶인 Drone이 남지 않는다.

## 확인 필요

레거시 `bomb_drone_diamond`의 Bomb는 Slot0(`top`)이고 `center`에는 Drone이 있다. [Diamond5](../formations/diamond-5.md)의 “중앙 Bomb” 표기와 다르다. 풀에서 빠졌으므로 프리셋을 지울지 남길지와 함께 정한다.
