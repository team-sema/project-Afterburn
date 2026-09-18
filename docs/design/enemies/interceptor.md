# Interceptor

## 외형

![Interceptor](sprites/enemy_interceptor.svg)

아래를 향한 **화살촉·전투기** 실루엣. 쓸린 날개와 중앙 코어 구멍이 있다. 일반 적과 달리 **주황 네온**이라 측면 진입 위협으로 눈에 띈다.
- 스프라이트: `assets/svg/enemy_interceptor.svg`
- 틴트: 주황 글로우 · 따뜻한 화이트 코어 (`interceptor_enemy.tscn`)

## 의도

**옆·대각에서 짧게 스치는** 교전.
위에서 천천히 내려오는 편대와 달리, 좌우에서 경고를 준 뒤 빠르게 지나가며 한 번 갈긴다. 세로 스크롤만 보고 있으면 맞는다는 감각을 깨뜨린다.

## 플레이어가 고민할 점

- 가장자리 경고를 보고 시선과 히트박스를 옮기기
- 짧은 사격 타이밍에만 반응하기 (질질 끄는 교전이 아님)
- 지나간 뒤 추격할 가치가 있는지 판단하기 (화면 밖으로 나가면 보상 없음 — 구현)

## 하지 않는 것

- 상단에 오래 떠서 탄막을 까는 타입 (Caster 몫)
- 느린 하강 편대를 그대로 대체하는 적
- 화면 중앙에 눌러앉아 저격하는 타입 (Sniper 몫)

## 편대·Encounter에서의 역할

2기(pair)·3기(trio). 혼자 배회하는 Encounter는 두지 않는다.


## 확정 규칙·수치


| 항목 | 값 |
|------|-----|
| 씬 | `enemies/interceptor_enemy.tscn` (`normal_enemy` 상속) |
| HP | **50** |
| 점수·XP | Drone과 동일 |
| 최소 Threat | 1 (pair) / 3 (trio) |
| 비주얼 | `enemy_interceptor.svg` (기수 +Y) |

## 고속 공격 패스 (유닛·공통)

- `EnemySpawner`가 `ForwardAttackRun`을 좌→우 / 우→좌 랜덤 + dive 각도(약 15~29°)로 배치
- 스폰 Y: VisibleRect 높이의 약 16~38% 상단 밴드
- `start_delay=0.9` 동안 `EntryWarningComponent`가 좌/우 등장 가장자리에 경고 (화살표는 스폰 쪽)
- `ForwardAttackRunMovementStep`: 편대 루트를 진행 방향으로 회전 후 local forward 210px/s. clamp·bounce·재추적 없음
- 화면 진입 후 **0.7초** 사격 창 · **5발 burst 1회만** (`gap` 0.1, `rest` 10으로 재공격 차단)
- 탄: 매 볼리 플레이어 재조준 · **250px/s**. `aimed_burst_pattern.gd`와 신규 바늘탄을 사용한다. 마지막 볼리 뒤 10초 휴식도 일정에 남겨 활성 기간 중 기존 위협도 보고를 보존하며, 0.7초 사격 창이 다음 묶음을 차단한다.
- Drone에서 상속한 전역 일반 적 사격 안전선을 사용하며, 플레이필드 높이의 70% 아래에서는 남은 볼리를 발사하지 않음
- 생존 기체는 DespawnArea 이탈 시 보상 없음 (`no_health` 없음)

## 조합

| Encounter | 진형 |
|-----------|------|
| `interceptor_pair` | [interceptor-pair](../formations/interceptor-pair.md) (36px 가로 2슬롯) |
| `interceptor_trio` | [V3](../formations/v3.md) |

단독 Encounter 없음.

→ [Encounter 카탈로그](../encounters/catalog.md)


## 완료 조건·검증

- 기획에 명시된 등장 조건, 공격 예고·실행·종료와 보상 처리를 확인한다.
- 관련 씬의 수치와 위 규칙을 대조하고, 행동 변경 시 해당 적의 스모크 테스트를 실행한다.
- `enemy_pattern_migration_smoke_test.gd`에서 진입 활성화·발수·탄속·위협도·사격 창 종료를 검증하고, `interceptor_enemy_smoke_test.gd`에서 실제 편대의 경고·패스·발사·화면 이탈·보상을 검증한다.

## 변경 이력

- 2026-09-14: 외형(스프라이트 미리보기) 추가.
- 2026-09-13: 기획 의도와 구현 규칙을 통합.


| 날짜 | 변경 |
|------|------|
| 2026-08-30 | 한국어 문장 정리 |
| 2026-08-30 | 기획 문서 |
