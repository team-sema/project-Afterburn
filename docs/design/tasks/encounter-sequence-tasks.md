# Tasks — encounter-sequence

시스템 스펙: [encounter-sequence.md](../history/encounter-sequence.md) · 현황: [run-pacing.md](../run-pacing.md)

## 1. 시퀀스 Resource

- 목적: 개발자가 에디터에서 편집하는 데이터 모델.
- 수정 예상: `resources/encounter_sequences/encounter_sequence.gd` · `encounter_sequence_phase.gd` · `encounter_sequence_step.gd` · `encounter_wave.gd` (신규)
- 수정 금지: `resources/encounters/*` (Preset·Pool은 그대로 사용)
- 완료 조건: 네 Resource에 스펙 필드가 있고 `get_validation_errors()`/`validate()`가 미정의 토큰·빈 후보·`max < min` 간격을 잡는다. Step/Wave는 `roll_post_delay(rng)`/`roll_interval(rng)`로 범위 랜덤을 낸다. Phase는 `pattern`을 토큰 배열로 풀어 주는 `get_tokens()`를 제공한다.

## 2. EncounterRun (편대 추적)

- 목적: 스폰된 편대의 적이 모두 사라졌는지 `wait_for_clear`가 알 수 있게 한다.
- 수정 예상: `encounters/encounter_run.gd` (신규) · `formations/formation_controller.gd` (`member_spawns_finished` 시그널 · `are_member_spawns_finished()`)
- 수정 금지: `enemies/enemy_spawner.gd`
- 완료 조건: 편대 해산·재부모화 후에도 추적이 이어지고, 마지막 멤버가 트리를 떠나면 `completed`를 낸다.

## 3. 기존 컨트롤러 훅

- 목적: Director가 타이머 대신 명시적으로 스폰·관문을 요청할 수 있게 한다.
- 수정 예상: `enemy_generator.gd` (`automatic_spawning_enabled` · `spawn_preset_tracked` · `pick_from_pool`) · `augment_progression_controller.gd` (`automatic_elite_milestones` · `request_elite_milestone()`) · `threat_elite_controller.gd` (`set_next_gate(preset, is_boss)`)
- 수정 금지: 탄소거 보상 컨트롤러 · 오퍼 컨트롤러
- 완료 조건: 플래그가 기본 true일 때 기존 동작과 완전히 동일. override가 있으면 교대 규칙 대신 그 preset을 소환하고 초기화한다. 보스는 `is_boss` 부여·엘리트 HP 공식 미적용.

## 4. EncounterDirector

- 목적: 시퀀스를 순차 실행한다.
- 수정 예상: `encounters/encounter_director.gd` (신규)
- 수정 금지: `enemies/*.tscn` 수치
- 완료 조건: Phase·pattern·post_delay·WAVE interval·ELITE/BOSS 관문 대기·on_complete가 스펙대로. 일시정지 시 정지. 보조 씬 인스턴스에서는 autostart 안 함.

## 5. 기본 데이터 · 씬 연결

- 목적: 정상 플레이가 새 시퀀스로 돌아가면서 체감이 유지된다.
- 수정 예상: `resources/encounter_sequences/main_encounter_sequence.tres` · `waves/drone_swarm_wave.tres` (신규) · `gameplay.tscn` (Director 노드)
- 수정 금지: `resources/encounters/pools/main_encounter_pool.tres`
- 완료 조건: 스펙 "기본 시퀀스"와 동일한 토큰·패턴. 게임 진입 시 첫 엘리트 ≈60초.

## 6. 테스트

- 수정 예상: `tests/encounter_sequence_smoke_test.gd` (신규). 기존 테스트는 Director가 보조 씬에서 autostart 하지 않으므로 수정 없음.
- 완료 조건: 신규 smoke PASS · 기존 적/엘리트 회귀 PASS · `--headless --editor --quit` 파싱 통과.

## 7. 현황 스펙

- 수정 예상: `docs/design/run-pacing.md` · `docs/design/overview.md` · `docs/design/encounters/index.md` · `docs/design/components.md`
- 완료 조건: 일반 스폰·엘리트 트리거 정본이 "시퀀스 데이터"로 갱신되고, 적 계층에 시퀀스 층이 들어간다.

## 상태

| Task | 상태 | 확인 |
|---|---|---|
| 1 Resource | 완료 | `encounter_sequence_smoke_test` — 검증·토큰 파싱·범위 롤 |
| 2 EncounterRun | 완료 | 같은 테스트 — 실제 `gameplay.tscn` 스폰 추적 |
| 3 컨트롤러 훅 | 완료 | 기존 `threat_elite_progression`·`augment_progression`·`enemy_threat_spawn`·`bullet_cancel_reward`·`pause` PASS |
| 4 Director | 완료 | 페이크 컨트롤러 — a/b/c 순서 · wait_for_clear · 게이트 종료 후 재개 · BOSS 건너뜀 · post_delay 대기 · STOP 완료 |
| 5 데이터·씬 | 완료 | `main_encounter_sequence.tres` validate · Director 노드 · 보조 씬에서 idle |
| 6 테스트 | 완료 | 신규 PASS · 회귀 PASS · 에디터 파싱 통과 |
| 7 현황 스펙 | 완료 | run-pacing · overview · encounters/index · components |

## 변경 이력

- 2026-09-10: 구현 완료. 간격을 `[min, max]` 랜덤으로.
- 2026-09-10: 초안.
