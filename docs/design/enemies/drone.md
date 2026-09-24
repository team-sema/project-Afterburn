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
| `bomb_drone_diamond` | 호위 |
| `v7_drone_down` / `x9_drone_down` | 하강 후 산개 |
| `x9_caster_drone_orbit` | 궤도 호위 |

→ [Encounter 카탈로그](../encounters/catalog.md) · [진형 배치 목록](../formations/index.md)


## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
