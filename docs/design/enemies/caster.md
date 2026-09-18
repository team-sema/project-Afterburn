# Caster

## 외형

![Caster](sprites/enemy_caster.svg)

**육각·크리스탈**에 가까운 실루엣. 바깥 고리와 안쪽 마름모가 겹쳐 “탄막 포탑”처럼 보인다. Drone보다 덩치감이 있다.
- 스프라이트: `assets/svg/enemy_caster.svg`
- 틴트: 분홍 네온 (베이스 상속)

## 엘리트 외형 시안

![Elite Caster concept](sprites/enemy_elite_caster.svg)

- 원형의 고리·중앙 마름모를 계승한 **공중 탄막 발생기**. 작은 세로형 크리스탈을 중심에 두고, 상하가 열린 각진 고리 두 조각을 몸체와 떨어뜨려 배치한다. 코어는 이전 시안의 가로·세로 60%로 줄이고 고리 중앙에 맞춰, 고리 안에 떠 있는 비율로 표현한다.
- 기존 Elite Fighter / Elite Awl의 흰색 마스크·날카로운 투명 절개를 공유한다. 색상은 엘리트 공용 적색/분홍 글로우와 연분홍 흰색 코어를 기준으로 한다.
- 크리스탈 내부의 마름모 절개와 하단의 가는 틈으로 결정의 면을 표현한다. 고리와 코어 사이에는 넓은 빈 공간을 남긴다. 후방 하우징·측면 돌기·둥근 장갑 덩어리는 제거한다.
- 에셋: `assets/svg/enemy_elite_caster.svg` (128×160). 시안 표시 배율은 기존 엘리트와 같은 0.25 × 1.35이며, 확대와 약 43×54px 크기에서 확인한다.
- 현재는 외형 시안이다. 전용 씬·공격 패턴·수치·Threat 편성은 미정이며, 실제 스폰에는 연결하지 않는다.
- 미리보기: `artifacts/elite_caster_design.png`, 재생성: `tools/run-godot.cmd --script res://artifacts/preview_elite_caster.gd`.

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
- `EnemyShootComponent`와 `caster_pattern.gd`로 링 일정을 실행한다. 실제 씬의 기존 값인 16발 × 5링을 보존한다(이전 문서의 20발 표기를 정정).
- 최초 지연 1.2초, 링 간격 0.1초, 마지막 링 뒤 휴식 4.8초, 탄속 95px/s. 오른쪽에서 시작해 링마다 7° 회전하며 묶음마다 초기화한다.
- 신규 바늘탄 몸체를 사용한다. 화면 진입 대기·하단 사격 금지선은 적용하지 않는다. ACTION_RATE만 적용하며 포화 사격의 추가 발수·펼침각은 기존처럼 적용하지 않는다.
- 레거시 상태머신은 제거하며 `EnemyShootComponent`는 유지한다. Radial 전용 컴포넌트는 제거한다.

## 조합

| Encounter | 역할 |
|-----------|------|
| `caster_single` | [Single](../formations/single.md) 1슬롯 → 즉시 해제 → 개별 패트롤 |
| `x9_caster_drone_orbit` | [X9](../formations/x9.md) 중심 Caster + Drone 공전 |

→ [Encounter 카탈로그](../encounters/catalog.md)


## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
- `enemy_pattern_migration_smoke_test.gd`에서 링 발수·주기·회전 초기화·ACTION_RATE·발수 증강 제외를 검증한다. `caster_top_orb_barrage_smoke_test.gd`에서 상단 진입·순찰과 공통 발사 연결을 검증한다.

## 변경 이력

- 2026-09-15: 캐스터 엘리트 외형 시안 추가. 둥근 장갑 형태에서 긴 크리스탈과 떠 있는 열린 고리로 수정.
- 2026-09-14: 외형(스프라이트 미리보기) 추가.
- 2026-09-13: 기획 의도와 구현 규칙을 통합.


| 날짜 | 변경 |
|------|------|
| 2026-08-30 | 한국어 문장 정리 |
| 2026-08-30 | 기획 문서 |
