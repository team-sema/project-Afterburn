# Feature: 적 등장 시퀀스 (Encounter Sequence)

## 목적

지금은 `EnemyGenerator`가 2.8초 타이머마다 `MainEncounterPool`에서 랜덤 Encounter를 뽑고, 엘리트는 60초 타이머로 따로 온다. 적이 **어떤 순서로, 어떤 간격으로** 나오는지 개발자가 설계할 수 없다.

이 기능은 한 판의 적 등장을 **데이터(Resource)로 짠 시나리오**로 바꾼다. 개발자는 아래 네 종류의 스텝을 문자열 패턴으로 나열해 Phase를 만들고, 각 스텝이 무엇을 얼마 간격으로 내보내는지 에디터에서 조정한다.

| 토큰(예) | 종류 | 뜻 |
|---|---|---|
| `a` | `NORMAL` | 일반 적 편대 1개 |
| `b` | `WAVE` | 지정한 편대 여러 개를 짧은 간격으로 연속 투입 |
| `c` | `ELITE` | 엘리트 관문 (처치 → 보상 → Threat +1 → 적 증강 오퍼) |
| `d` | `BOSS` | 보스 관문 (보스 콘텐츠는 미구현 · 구조만 마련) |

예: 한 Phase의 패턴 `a a a a b a a a b a a c a a b b a a a d`.

기존 `EncounterPreset` · `EncounterPool` · `EnemySpawner` · `ThreatEliteController` · 탄소거 보상 흐름은 그대로 **재사용**한다. 새로 만드는 것은 "무엇을 언제 요청하는가"를 정하는 층이다.

## 데이터 모델

경로: `resources/encounter_sequences/`

### `EncounterSequence` (Resource)

| 필드 | 의미 |
|---|---|
| `sequence_id: StringName` | slug |
| `shared_steps: Array[EncounterSequenceStep]` | 모든 Phase가 공유하는 토큰 정의 (`a`·`b`·`c`·`d` …) |
| `phases: Array[EncounterSequencePhase]` | 순서대로 실행 |
| `on_complete: enum` | `REPEAT_LAST_PHASE`(기본) · `STOP` |

### `EncounterSequencePhase` (Resource)

| 필드 | 의미 |
|---|---|
| `phase_id: StringName` | 식별자 |
| `pattern: String` | 공백으로 구분한 토큰 나열. 예 `"a a a b a a c"` |
| `repeat_count: int` | Phase 반복 횟수 (기본 1) |
| `steps: Array[EncounterSequenceStep]` | 이 Phase에서만 쓰는 토큰 정의. 같은 토큰이 `shared_steps`에도 있으면 **Phase 쪽이 우선** |

패턴에 등장하는 모든 토큰은 `steps` 또는 `shared_steps`에 정의돼 있어야 한다. 토큰은 공백이 없는 임의 문자열이라 `a`, `a_fast`, `b2` 처럼 변형을 만들 수 있다.

### `EncounterSequenceStep` (Resource)

공통

| 필드 | 의미 |
|---|---|
| `token: StringName` | 패턴에서 부르는 이름 |
| `kind: enum` | `NORMAL` · `WAVE` · `ELITE` · `BOSS` |
| `post_delay_min` · `post_delay_max: float` | 다음 스텝까지 대기(초). 매번 `[min, max]` 균등 랜덤. "a와 a 사이의 간격"이 여기. 기본 2.8 ~ 3.1 (현재 타이머 2.8 + 0~0.3 지터와 같음) |

`post_delay`를 재는 기준 시점은 종류마다 다르다.

| 종류 | 기준 |
|---|---|
| `NORMAL` | 편대를 스폰한 순간 |
| `WAVE` | 마지막 편대를 스폰한 순간 |
| `ELITE` · `BOSS` | 관문이 닫힌 순간 (처치 → 보상 → 적 증강 오퍼 완료) |

`NORMAL`

| 필드 | 의미 |
|---|---|
| `encounter_presets: Array[EncounterPreset]` | 후보. 1개면 고정, 여러 개면 균등 랜덤 (직전 것과 같은 id는 대안이 있을 때 피함) |
| `encounter_pool: EncounterPool` | `encounter_presets`가 비었을 때 사용. 현재 Threat 기준 weighted 랜덤 (지금의 랜덤 스폰과 동일) |

`WAVE`

| 필드 | 의미 |
|---|---|
| `wave: EncounterWave` | 편대 목록과 내부 간격 |

`ELITE`

| 필드 | 의미 |
|---|---|
| `elite_preset: EncounterPreset` | 등장할 엘리트 Encounter (`threat_elite_single` · `threat_elite_awl` 등). 비우면 기존 규칙(짝수 Threat 사격형·홀수 돌격형) |
| `wait_for_clear: bool` | true(기본)면 앞선 스텝들이 만든 적이 전부 사라질 때까지 기다린 뒤 소환 |

`BOSS`

| 필드 | 의미 |
|---|---|
| `boss_preset: EncounterPreset` | 보스 Encounter. 멤버 1기 |
| `wait_for_clear: bool` | 엘리트와 동일 (기본 true) |

### `EncounterWave` (Resource)

| 필드 | 의미 |
|---|---|
| `wave_id: StringName` | 식별자 |
| `encounter_presets: Array[EncounterPreset]` | **순서대로** 투입되는 편대 |
| `interval_min` · `interval_max: float` | 편대 사이 간격(초). 매번 `[min, max]` 균등 랜덤. 기본 1.0 ~ 1.0 |

Wave는 여러 스텝·Phase에서 재사용할 수 있으므로 별도 `.tres`로 둔다.

## 동작 조건

### 실행기 — `EncounterDirector` (Node, `gameplay.tscn` 자식)

- 시퀀스를 **시작하는 순간** `EnemyGenerator`의 타이머 스폰을 끄고(`set_automatic_spawning_enabled(false)`), `AugmentProgressionController`의 60초 자동 엘리트 마일스톤도 끈다(`automatic_elite_milestones = false`). 씬 파일의 기본값은 그대로 true라서, Director가 시작하지 않으면(테스트가 보조 씬으로 띄운 경우) 두 컨트롤러는 지금과 완전히 같게 동작한다.
- `phases`를 순서대로, 각 Phase의 `pattern`을 토큰 단위로 순서대로 실행한다.
- 스텝의 기준 시점(위 표)부터 `post_delay`(랜덤 롤)를 재고, 지나면 다음 스텝을 시작한다. 앞 스텝의 적이 살아 있어도 기다리지 않는다 (`ELITE`·`BOSS`의 `wait_for_clear`만 예외).
- 스텝 종류별:
  - `NORMAL`: 편대 1개를 `EnemyGenerator`를 통해 스폰. `encounter_pool`을 쓸 때만 현재 Threat와 `min_threat`를 본다. `encounter_presets`로 직접 지정한 편대는 Threat와 무관하게 등장한다 (개발자 의도 우선). 어느 쪽이든 기존 `resolve_normal_preset`(탱커 생존 시 sniper 보강 대체)은 그대로 적용.
  - `WAVE`: `wave.encounter_presets`를 `interval`(롤) 간격으로 순서대로 스폰. 마지막 편대를 낸 시점부터 `post_delay`를 잰다.
  - `ELITE`: `wait_for_clear`면 추적 중인 모든 편대의 적이 사라질 때까지 대기 → `elite_preset`을 다음 관문 preset으로 지정 → 기존 엘리트 마일스톤을 연다 → 처치·탄소거 보상·Threat +1·적 증강 오퍼가 끝나 게이트가 닫히면 `post_delay` 뒤 다음 스텝.
  - `BOSS`: `ELITE`와 같은 관문 흐름을 따르되 `boss_preset`을 쓰고 소환된 적에 `is_boss = true`를 붙인다. HP는 엘리트 공식을 적용하지 않고 씬 값을 쓴다. `boss_preset`이 비어 있으면 경고 후 스텝을 건너뛴다.
- 관문 중(`ELITE`·`BOSS`) 일반 편대 스폰이 없는 것은 시퀀스가 순차 실행이므로 자연히 보장된다. 기존 `set_normal_spawns_paused`는 하위 호환으로 유지한다.
- Phase의 `repeat_count`를 채우면 다음 Phase. 마지막 Phase까지 끝나면 `on_complete`: `REPEAT_LAST_PHASE`는 마지막 Phase를 무한 반복, `STOP`은 더 이상 스폰하지 않는다.
- `EncounterRun`이 편대별로 스폰된 적을 추적한다. 편대가 해산해 개별 이동으로 바뀌어도 계속 추적하며, 모든 멤버가 사망·이탈하면 완료로 본다. `wait_for_clear`는 이것을 본다.
- 일시정지 중 모든 대기 타이머가 멈춘다 (`SceneTree` 타이머 · `process_always = false`).
- 테스트가 `gameplay.tscn`을 보조 씬으로 직접 인스턴스화할 때는 자동 시작하지 않는다 (`autostart`는 정상 게임 진입에만).

### 기존 시스템 변경

| 대상 | 변경 |
|---|---|
| `EnemyGenerator` | `automatic_spawning_enabled` + `set_automatic_spawning_enabled()` 추가. `spawn_preset_tracked(preset) -> EncounterRun`, `pick_from_pool(pool, rng) -> EncounterPreset` 공개. 타이머 로직은 유지 |
| `AugmentProgressionController` | `automatic_elite_milestones` 추가. 60초 로직을 `request_elite_milestone() -> bool`로 분리해 Director가 호출 |
| `ThreatEliteController` | `set_next_gate(preset, is_boss)`. 설정돼 있으면 교대 규칙 대신 사용하고 소환 후 초기화. 보스는 `is_boss` 부여·엘리트 HP 공식 미적용 |
| `FormationController` | `member_spawns_finished` 시그널 · `are_member_spawns_finished()` (EncounterRun 완료 판정용) |
| `gameplay.tscn` | `EncounterDirector` 노드 추가 · 기본 시퀀스 `main_encounter_sequence.tres` 연결 |

### 기본 시퀀스 (`main_encounter_sequence.tres`)

요청 예시처럼 **a/b/c/d가 섞인 한 패턴**을 끝까지 돌리고, 끝나면 같은 패턴을 반복한다 (`on_complete = REPEAT_LAST_PHASE`).

- `a` = `NORMAL` · `encounter_pool = main_encounter_pool` · `post_delay 2.8 ~ 3.1`
- `b` = `WAVE` · `drone_swarm_wave` (`drone_formation` 1편대 — 테스트용 라이트) · `post_delay 2.8 ~ 3.1`
- `c` = `ELITE` · `elite_preset` 비움(교대 규칙) · `wait_for_clear true` · `post_delay 2.8 ~ 3.1`
- `d` = `BOSS` · `boss_preset` 비움 (보스 미구현 → 건너뜀)
- Phase `main` 패턴: `a a a a b a a a b a a a c a a a a b a a a a d`
- Phase는 개발자가 구간을 나누고 싶을 때 쓰는 **선택 도구**일 뿐, opening/loop 같은 고정 개념이 아니다.

> 이전 초안의 `opening a×20 → c` + 별도 `loop`는 옛 60초 타이머 체감 맞추기를 위해 임의로 넣은 값이었다. 요청 예시와 다르므로 폐기.

## Feedback

- WAVE / ELITE / BOSS steps flash a small center-screen `EncounterStepWarning` (hard neon blink) before spawn/gate. NORMAL does not.
- 시퀀스 모드: `ProgressionHud`가 `EncounterDirector.sequence_progress_changed`를 받아 Threat 타이머 대신 `STAGE MM`과 스테이지 내 스텝 진행 바를 표시한다. STAGE는 패턴 1회가 끝날 때마다 +1. Threat 레벨은 HUD에 표시하지 않는다.
- 엘리트·보스 게이트 중에는 기존처럼 `ELITE ENGAGED`.
- Director가 없거나 시퀀스가 끝나면 기존 60초 카운트다운 표시로 돌아간다.

## 계산 방식

- 스텝 간 간격 = `randf_range(post_delay_min, post_delay_max)`. 기준 시점은 종류별 표 참고. 시드(`random_seed`)를 주면 재현 가능.
- `NORMAL` 후보 선택: `encounter_presets` 균등 랜덤(직전 id 회피) → 비었으면 `encounter_pool.choose(threat, rng, recent_ids)`.
- 엘리트 HP·보상·Threat 증가는 기존 공식 그대로 ([run-pacing](../../spec/run-pacing.md), [elite-fighter](../../spec/enemies/elite-fighter.md)).

## 예외 조건

- 패턴에 정의되지 않은 토큰 → `validate()` 실패, 게임 시작 시 assert.
- `NORMAL`에 후보도 풀도 없음 → validate 실패.
- 풀에서 현재 Threat에 후보가 없음 → 경고 후 스텝 건너뜀 (지금의 skip과 동일).
- `BOSS`에 `boss_preset` 없음 → 경고 후 건너뜀 (콘텐츠가 생기면 바로 채울 수 있게).
- `ELITE`/`BOSS`가 `wait_for_clear`로 대기 중 플레이어 사망 → 기존 게임오버 흐름. Director는 씬과 함께 소멸.
- Director가 씬에 없으면 `EnemyGenerator`·`AugmentProgressionController`는 지금과 완전히 같은 타이머 동작을 한다 (하위 호환 · 테스트 랩용).

## 영향받는 시스템

- 스폰: `enemy_generator.gd` · `enemies/enemy_spawner.gd`(변경 없음) · `formations/formation_controller.gd`(멤버 스폰 완료 시그널 추가)
- 관문: `threat_elite_controller.gd` · `augment_progression_controller.gd` · 탄소거 보상(변경 없음)
- 씬: `gameplay.tscn`
- 현황 스펙: `docs/spec/run-pacing.md`(일반 스폰·엘리트 트리거 정본 갱신) · `docs/spec/overview.md`(적 계층에 시퀀스 층 추가) · `docs/spec/encounters/index.md`(시퀀스 링크)

## Acceptance Criteria

- [x] `EncounterSequence` · `Phase` · `Step` · `Wave` Resource가 있고 `validate()`가 미정의 토큰·빈 후보·`max < min`을 잡는다. (smoke)
- [x] 패턴 문자열 `"a a b c"`가 토큰 순서대로 실행되며, 각 스텝은 `[post_delay_min, post_delay_max]`에서 롤한 시간 뒤에 다음 스텝을 시작한다. (smoke)
- [x] `NORMAL`은 `encounter_presets` 지정 시 그 편대만, 비었을 때 `encounter_pool`에서 Threat 기준으로 뽑는다. (presets 경로 smoke · pool 경로는 기본 시퀀스 플레이로 확인)
- [x] `WAVE`는 `EncounterWave`의 편대를 순서대로 `interval` 간격으로 낸다. (smoke · 실제 `gameplay.tscn`)
- [x] `ELITE`는 `wait_for_clear` 시 앞 편대 적이 모두 사라진 뒤 지정한 `elite_preset`을 소환하고, 게이트가 닫힌 뒤에만 다음 스텝으로 간다. 비우면 기존 교대 규칙. (smoke · 교대 규칙은 기존 회귀 테스트)
- [ ] `BOSS`는 `boss_preset`을 `is_boss`로 소환하고 관문 흐름을 따른다. 비어 있으면 경고 후 건너뛴다. (건너뜀 smoke · 소환은 보스 preset 생기면 확인)
- [x] Director가 시작하면 타이머 랜덤 스폰과 60초 자동 엘리트가 동작하지 않는다. 시작하지 않으면 기존과 동일하다. (smoke · 기존 회귀 PASS)
- [x] `on_complete = REPEAT_LAST_PHASE`면 마지막 Phase가 반복되고, `STOP`이면 스폰이 멈춘다. (STOP smoke · REPEAT는 기본 시퀀스 플레이)
- [ ] 편대 해산 후 개별 이동으로 바뀐 적도 `EncounterRun`이 끝까지 추적한다. (플레이 확인)
- [ ] 일시정지 중 스텝 진행이 멈춘다. (Timer 자식 노드 — 플레이 확인)
- [ ] 기본 `main_encounter_sequence.tres`가 요청형 a/b/c/d 혼합 패턴을 반복한다. (플레이 확인)
- [x] headless smoke 테스트: 검증·패턴 확장·스텝 순서·엘리트 대기·on_complete. 기존 Threat/엘리트 회귀 테스트 PASS.
- [x] `docs/spec/run-pacing.md` · `overview.md` · `encounters/index.md` · `components.md`가 구현과 일치한다.

## 구현 메모

- 실행은 `await` 기반 순차 코루틴 하나로 둔다. 상태 머신을 따로 만들지 않는다.
- 토큰 정의는 `Array[EncounterSequenceStep]`(각 `token` 필드)로 둔다. 인스펙터에서 Resource 배열이 Dictionary보다 편하다.
- 보스 콘텐츠(씬·패턴·보상)는 이 피쳐 범위 밖. `d`는 구조만.
- 랜덤은 `RandomNumberGenerator`를 주입 가능하게 해 테스트를 재현 가능하게 한다.

## 변경 이력

- 2026-09-13: 기본 시퀀스를 요청 예시형 혼합 패턴 1개 + 반복으로 교체. opening a×20 임의안 폐기.
- 2026-09-10: 간격을 고정값 대신 `[min, max]` 범위 랜덤으로 변경. 관문 스텝의 간격 기준은 게이트 종료 시점.
- 2026-09-10: 초안 — 토큰 패턴 기반 Phase · NORMAL/WAVE/ELITE/BOSS 스텝 · Director가 타이머 스폰·자동 엘리트를 대체.
