# 런 · 페이싱

한 판의 **시간·Threat·스폰 주기·엘리트 게이트**. 개별 적/진형/조합 수치는 하위 문서로.

## 플레이어 오퍼

- 적 처치 → XP → 임계 충족 후 **`C`** 로 플레이어 오그먼트 오픈
- 상세 풀·리롤: [오그먼트](#augments)

## 일반 Encounter 스폰

- 주기: **2.8초 + 0~0.3초** 지터 (`EnemyGenerator`)
- 선택: `MainEncounterPool` weighted random 1회
- 직전 **2개** Encounter id는 후보에서 제외 (대안이 있을 때)
- weight · min_threat · 등록 목록: [Encounter 카탈로그](#encounters/catalog)

## Threat · 엘리트 게이트

우선순위(겹칠 때): `boss > elite > augment offer > normal encounter` (보스는 미구현).

| 단계 | 동작 |
|------|------|
| 60초 타이머 완료 | 사격형 `threat_elite_single` / 돌격형 `threat_elite_awl` 교대로 1기 (`ThreatEliteController`) |
| 엘리트 전투 중 | 일반 Encounter 타이머 **정지** · 기존 일반 적 유지 |
| 엘리트 처치 | 전투 정지 → 적탄을 XP로 변환 → 화면의 모든 XP 강제 회수 |
| XP 회수 완료 | Threat **+1** → 적 증강 3지선다 |
| 오퍼 완료 | 일반 스폰·다음 Threat 타이머 재개 |
| 전투·오퍼 중 | Threat 시간 **누적 안 함** (연속 엘리트 방지) |

첫 엘리트: Threat **2** 사격형. Threat **3** 돌격형, 이후 짝수 Threat 사격형·홀수 Threat 돌격형으로 교대한다. 공통 HP 공식은 [elite-fighter](#enemies/elite-fighter), 돌격 규칙은 [elite-awl](#enemies/elite-awl).

탄소거 보상 중에는 전투 전체와 플레이어 오그먼트 `C` 입력을 잠근다. 적탄 1발은 XP 1로 변환되며, 기존 XP와 엘리트 확정 드롭까지 실제로 수집된 뒤에만 적 오그먼트 오퍼가 열린다. 아직 미구현인 보스도 향후 같은 공용 보상 컨트롤러를 호출한다.

## Threat별 로스터 요지

- **Threat 1:** Drone·Striker 호위·Awl·Bomb 다이아·Interceptor pair 등 (catalog)
- **Threat 2+:** `tanker_guard_sniper` (탱커 생존 시 sniper reinforcement)
- **Threat 3+:** Caster · V7/X9 하강 · X9 orbit · Interceptor trio

## 관련

- [적](#enemies) · [진형](#formations) · [Encounter](#encounters)
- 설계 초안(TBD 보스): `docs/design/systems/threat-elite-boss-loop.md`

## 변경 이력

- 2026-09-07: 사격형·돌격형 엘리트 교대 출현 규칙 반영.
