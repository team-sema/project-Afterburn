# 런 · 페이싱

한 판의 **시간·Threat·등장 순서·엘리트 게이트**. 개별 적/진형/조합 수치는 하위 문서로.

## 플레이어 오퍼

- 적 처치 → XP → 임계 충족 후 **`C`** 로 플레이어 오그먼트 오픈
- 상세 풀·리롤: [오그먼트](#augments)

## 등장 시퀀스 (`EncounterDirector`)

무엇이 언제 나오는지는 **데이터 시퀀스** `resources/encounter_sequences/main_encounter_sequence.tres` 가 정한다. `gameplay.tscn`의 `EncounterDirector`가 런 시작과 함께 재생하며, 그 순간 `EnemyGenerator` 타이머와 `AugmentProgressionController` 60초 엘리트 타이머를 **꺼서 대체**한다 (테스트처럼 Director가 시작하지 않으면 두 타이머는 예전 그대로 동작).

- **Phase**: 공백으로 나눈 토큰 패턴 (`"a a a b a a c"`) + `repeat_count`. 순서대로 실행.
- **Step(토큰)**: 종류 `NORMAL` / `WAVE` / `ELITE` / `BOSS` + `post_delay_min~max`. 시퀀스 공용(`shared_steps`) 또는 Phase 로컬(`steps`, 같은 토큰이면 우선).
- **다음 스텝까지 간격**: 매 스텝 `[post_delay_min, post_delay_max]` 균등 랜덤. 기준 시점 — NORMAL: 스폰 순간 · WAVE: 마지막 편대 스폰 순간 · ELITE/BOSS: 게이트가 닫힌 순간. 앞 스텝 적이 살아 있어도 기다리지 않는다.
- 마지막 Phase가 끝나면 `on_complete` — `REPEAT_LAST_PHASE`(기본) 또는 `STOP`.

| 종류 | 무엇을 | 후보 선택 |
|---|---|---|
| `NORMAL` | 편대 1개 | `encounter_presets` 지정 시 균등 랜덤(직전 id 회피, **Threat 무시**) · 비었으면 `encounter_pool.choose(현재 Threat)` (weight·min_threat·직전 2 id 제외 그대로) |
| `WAVE` | `EncounterWave` 의 `encounter_presets`를 **순서대로**, 편대 사이 `interval_min~max` 랜덤 | 고정 순서 |
| `ELITE` | 아래 엘리트 게이트를 연다 | `elite_preset` 지정 시 그 preset, 비우면 교대 규칙 |
| `BOSS` | 엘리트 게이트와 같은 흐름 + `is_boss` (엘리트 HP 공식 미적용) | `boss_preset` 비어 있으면 경고 후 **건너뜀** |

`ELITE`/`BOSS`는 `wait_for_clear`(기본 true)면 Director가 추적 중인 모든 편대의 적이 사라진 뒤 게이트를 연다.

WAVE·ELITE·BOSS 스텝은 스폰/게이트 직전에 맵 중앙에 작은 `EncounterStepWarning`이 점멸한다 (NORMAL은 없음).

**현재 기본 시퀀스**

| 토큰 | 종류 | 내용 | post_delay |
|---|---|---|---|
| `a` | NORMAL | `MainEncounterPool` 랜덤 | 2.8 ~ 3.1초 |
| `b` | WAVE | `drone_swarm_wave`: `drone_formation` 1편대 (테스트용 라이트) | 2.8 ~ 3.1초 |
| `c` | ELITE | 교대 규칙 · wait_for_clear | 2.8 ~ 3.1초 |
| `d` | BOSS | 비움 (보스 미구현 → 건너뜀) | — |

- Phase `main`: `a a a a b a a a b a a a c a a a a b a a a a d`
- 끝나면 같은 Phase를 반복 (`REPEAT_LAST_PHASE`). Phase는 패턴을 담는 단위일 뿐, opening/loop 고정 구조가 아니다.

개발자는 `.tres`의 패턴 문자열·토큰 정의만 고쳐 시나리오를 바꾼다. 설계·AC: `docs/design/systems/encounter-sequence.md`.

## 일반 Encounter 스폰 (타이머 — Director 미사용 시)

- 주기: **2.8초 + 0~0.3초** 지터 (`EnemyGenerator`, `automatic_spawning_enabled`)
- 선택: `MainEncounterPool` weighted random 1회
- 직전 **2개** Encounter id는 후보에서 제외 (대안이 있을 때)
- weight · min_threat · 등록 목록: [Encounter 카탈로그](#encounters/catalog)

## Threat · 엘리트 게이트

우선순위(겹칠 때): `boss > elite > augment offer > normal encounter` (보스는 미구현).

| 단계 | 동작 |
|------|------|
| 게이트 오픈 (`ELITE` 스텝, 또는 Director 미사용 시 60초 타이머) | 사격형 `threat_elite_single` / 돌격형 `threat_elite_awl` 교대로 1기 (`ThreatEliteController`). 스텝의 `elite_preset`이 있으면 그 preset |
| 엘리트 전투 중 | 일반 Encounter 스폰 **정지** (시퀀스도 대기) · 기존 일반 적 유지 |
| 엘리트 처치 | 전투 정지 → 적탄을 XP로 변환 → 화면의 모든 XP 강제 회수 |
| XP 회수 완료 | Threat **+1** → 적 증강 3지선다 |
| 오퍼 완료 | 게이트 닫힘 → 시퀀스 다음 스텝 (타이머 모드면 일반 스폰·다음 Threat 타이머 재개) |
| 전투·오퍼 중 | Threat 시간 **누적 안 함** (연속 엘리트 방지) |

첫 엘리트: Threat **2** 사격형. Threat **3** 돌격형, 이후 짝수 Threat 사격형·홀수 Threat 돌격형으로 교대한다. 공통 HP 공식은 [elite-fighter](#enemies/elite-fighter), 돌격 규칙은 [elite-awl](#enemies/elite-awl).

탄소거 보상 중에는 전투 전체와 플레이어 오그먼트 `C` 입력을 잠근다. 적탄 1발은 XP 1로 변환되며, 기존 XP와 엘리트 확정 드롭까지 실제로 수집된 뒤에만 적 오그먼트 오퍼가 열린다. 아직 미구현인 보스도 향후 같은 공용 보상 컨트롤러를 호출한다.

## Threat HUD

- **시퀀스 모드** (`EncounterDirector` 실행 중): `STAGE MM` + 바 = 현재 스테이지(패턴 1회) 안 스텝 진행도. 패턴이 반복될 때마다 STAGE +1. 엘리트 게이트 중에는 `STAGE MM   ELITE ENGAGED`.
- **타이머 모드** (Director 미사용): 기존 `MM:SS` 카운트다운 (Threat 숫자는 HUD에 표시하지 않음).

## Threat별 로스터 요지

- **Threat 1:** Drone·Striker 호위·Awl·Bomb 다이아·Interceptor pair 등 (catalog)
- **Threat 2+:** `tanker_guard_sniper` (탱커 생존 시 sniper reinforcement)
- **Threat 3+:** Caster · V7/X9 하강 · X9 orbit · Interceptor trio

## 관련

- [적](#enemies) · [진형](#formations) · [Encounter](#encounters)
- 설계 초안(TBD 보스): `docs/design/systems/threat-elite-boss-loop.md`

## 변경 이력

- 2026-09-13: 기본 시퀀스를 요청 예시형 `a/b/c/d` 혼합 패턴 1개 + 반복으로 교체. 임의 opening(`a×20→c`)/loop 분리 폐기.
- 2026-09-13: Threat HUD를 시퀀스 진행도로 전환. `drone_swarm_wave`를 드론 1편대로 축소(테스트 난이도).
- 2026-09-10: `EncounterDirector` + 데이터 시퀀스(토큰 패턴 Phase · NORMAL/WAVE/ELITE/BOSS 스텝 · 범위 랜덤 간격)가 타이머 스폰·60초 엘리트 타이머를 대체.
- 2026-09-07: 사격형·돌격형 엘리트 교대 출현 규칙 반영.
