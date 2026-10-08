# Drone

## 외형

![Drone](sprites/enemy_drone.svg)

분홍 네온의 빛나는 **작은 다이아몬드** 실루엣. 몸통 안에 마름모 구멍이 있고, 좌우에 짧은 날개 팁이 있다. 화면에서 가장 흔한 “잡몹” 실루엣이다.
- 스프라이트: `assets/enemies/enemy_drone.svg`
- 틴트: 분홍 글로우 · 거의 흰 코어 (베이스 `enemy.tscn`)

## 의도

화면을 채우는 **기본 밀도**, 그리고 내버려 두면 계속 맞는 **탄압**.
잡몹처럼 보이지만, 방치하면 편대가 플레이 공간을 조금씩 잠식한다. 초반부터 나와 **이동과 사격의 기본 리듬**을 잡게 한다.

## 플레이어가 고민할 점

- 호위일 때: 편대 전체를 지울지, 핵만 노릴지
- 산개·대각으로 움직이는 경로를 미리 읽고 피하기
- 화력을 나눠 쓸지, 한 줄부터 지울지

## 하지 않는 것

- 혼자 보스급으로 버티는 위협
- 긴 예고가 있는 특수기 (Sniper / Awl / Bomb 몫)
- 화면을 통째로 덮는 탄막 (Caster 몫)

## 편대·Encounter에서의 역할

거의 모든 편대의 **살과 호위**. Striker·Bomb·Caster 궤도 같은 조합의 몸통 역할.
슬롯 기하·배치 그림은 [진형 카탈로그](../formations/index.md) (드론 Encounter 대응 표 포함). 멤버·이동 수치는 [Encounter 카탈로그](../encounters/catalog.md).


## 확정 규칙·수치


| 항목 | 값 |
|------|-----|
| 씬 | `enemies/normal_enemy.tscn` |
| HP | 28 |
| 점수 | 5 |
| 최소 Threat | 1 |
| 사격 | `EnemyShootComponent` 조준 단발 |

## Threat 1 사격

- Drone은 `EnemyShootComponent.pattern_script`에 `patterns/drone_pattern.gd`를 지정한다. Kind.BULLET + needle.tres 외형 + 직진 Behavior를 사용한다. 기존 중심 텍스처·두 가산 발광층과 4×8px 직사각형 판정(로컬 y=1)을 새 배치 렌더러로 그린다. 다이아몬드 꼬리는 공통 입자 관리기로 재현하고 초기 확대/섬광은 포함하지 않는다. 조준 단발·4.5초 반복·105px/s는 유지한다.
- 초기 지연·사격 안전선·강화 연결은 컴포넌트가 관리하고 발수·탄속·간격은 패턴을 따른다. Drone을 상속하는 Interceptor는 pattern_script를 null로 지정하여 기존 사격을 유지한다.

| `fire_interval` | 볼리 | 발수 | 탄속 | `initial_delay` |
|---|---|---|---|---|
| 4.5 | 1 | 1 | 105 | 1.5 |

이후 난이도는 적 오그먼트 `ACTION_RATE`가 BarragePlayer의 일정 배속을 올린다. 탄속과 Behavior 시간에는 배율이 없다. 표의 4.5초는 패턴의 wait 값이며 레거시 fire_interval 필드는 패턴 모드에서 무시된다.

전역 일반 적 사격 안전선을 사용하므로 중심점이 플레이필드 높이의 70% 아래로 내려가면 발사하지 않는다.

## 조합에서 쓰이는 곳

호위·편대 본체로 가장 많이 쓰인다. 유닛 수치만 여기; 배치·이동은 Encounter.

| Encounter | 역할 |
|-----------|------|
| `drone_formation` | 5기 대각 편대 본체 |
| `drone_zigzag_mirrored` | zigzag 편대 본체 |
| `striker_drone_diamond_5` / `_13` | 호위 |
| `v7_drone_down` / `x9_drone_down` | 하강 후 산개 |
| `x9_caster_drone_orbit` | 궤도 호위 |

→ [Encounter 카탈로그](../encounters/catalog.md) · [진형 배치 목록](../formations/index.md)

## 변종 (`enemies/variants/`)

같은 드론 실루엣에 색과 탄만 바꾼 세 변종이다. 각자 **회피 기술 하나**를 가르치며, 등장 작곡([런 페이싱](../run-pacing.md))에서 같은 교훈의 다른 교재로 쓴다. HP·점수·이동·사격 안전선·초기 지연 1.5초·휴식 4.5초는 원본과 같다. `normal_enemy.tscn`을 상속하므로 Drone 진화 카드의 치환 대상이 **아니다**(씬이 같을 때만 치환).

| 변종 | 씬 | 글로우 | 탄 | 가르침 |
|------|-----|--------|-----|--------|
| 산탄 드론 | `drone_spread.tscn` | 금색 | 금색 원탄 **3방향 24°** 부채꼴 1회 · 80px/s | 한 발이 아니라 **부채꼴 폭만큼** 비킨다. Striker 부채꼴의 예습 |
| 느린탄 드론 | `drone_slow.tscn` | 보라 | 보라 **대형 구탄** 1발 · 55px/s · 수명 8초 | 느린 탄은 오래 남아 **지금 안전한 자리가 곧 막힌다**. Caster 장판의 예습 |
| 정지탄 드론 | `drone_halt.tscn` | 적색 | 바늘탄 1발 120px/s → 0.3초에 **정지** → 0.4초 대기 → **붉게 변하고** 0.15초 뒤 표적으로 재조준(1440°/s·0.12초) → 190px/s 돌진 | 발사 전에 움직여도 소용없고 **붉어진 뒤 돌진할 때** 비킨다. Sniper 락온의 예습 |

- 산탄·느린탄은 `aimed_burst_pattern.gd`의 `shape`·`tint`·`trail` 파라미터로, 정지탄은 전용 [drone_halt_pattern.gd](../../../patterns/drone_halt_pattern.gd)로 쏜다. 정지탄은 포화 사격 발수 증강을 받지 않는다(`pattern_fire_volume_boost` 끔). 산탄·느린탄은 원본처럼 받는다.
- Encounter: `drone_spread_formation`(가로 5기 대각, Threat 1) · `drone_slow_zigzag`(V5 지그재그, Threat 2) · `drone_halt_formation`(가로 5기 대각, Threat 2). 풀 가중치는 [카탈로그](../encounters/catalog.md).
- 검증: `tests/drone_variants_test.gd`(탄 모양·속도·행동 순서·글로우 색·풀 Threat 관문), `tests/encounter_spawner_smoke_test.gd`(프리셋 스폰).

## 진화형 (`enemies/evolved/drone_evolved.tscn`)

적 증강 [진화: 연사 드론](../augments.md#진화-증강)을 고르면 이후 Drone이 이 씬으로 스폰된다. 기본 규칙은 원본과 같고 아래만 다르다.

| 항목 | 원본 | 진화형 |
|------|------|--------|
| HP | 28 | **40** |
| 사격 | `drone_pattern.gd` 조준 단발 | `aimed_burst_pattern.gd` 조준 **3연사** (`shots` 3 · `gap` 0.12 · `ways` 1) |
| 탄속 · 휴식 | 105 · 4.5초 | 105 · 4.5초 (마지막 탄 뒤) |

매 발 재조준한다. 포화 사격의 발수·펼침각은 각 연사 볼리에 적용된다.

## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
- 진화형은 HP 40으로 나오고, 4.5초마다 재조준 3연사를 쏜다.
