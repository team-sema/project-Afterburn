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
| 60초 타이머 완료 | `threat_elite_single` 1기 (`ThreatEliteController`) |
| 엘리트 전투 중 | 일반 Encounter 타이머 **정지** · 기존 일반 적 유지 |
| 엘리트 처치 | Threat **+1** → 적 증강 3지선다 |
| 오퍼 완료 | 일반 스폰·다음 Threat 타이머 재개 |
| 전투·오퍼 중 | Threat 시간 **누적 안 함** (연속 엘리트 방지) |

첫 엘리트: Threat **2**, HP 공식은 [elite-fighter](#enemies/elite-fighter).

## Threat별 로스터 요지

- **Threat 1:** Drone·Striker 호위·Awl·Bomb 다이아·Interceptor pair 등 (catalog)
- **Threat 2+:** `tanker_guard_sniper` (탱커 생존 시 sniper reinforcement)
- **Threat 3+:** Caster · V7/X9 하강 · X9 orbit · Interceptor trio

## 관련

- [적](#enemies) · [진형](#formations) · [Encounter](#encounters)
- 설계 초안(TBD 보스): `docs/design/systems/threat-elite-boss-loop.md`
