# Task: wave-pre-clear-gap

## Canonical docs

- [run-pacing.md](../run-pacing.md)

## Scope

- `resources/encounter_sequences/encounter_sequence_step.gd`
- `encounters/encounter_director.gd`
- `resources/encounter_sequences/main_encounter_sequence.tres`
- `resources/encounter_sequences/waves/drone_swarm_wave.tres`
- `docs/design/run-pacing.md`
- `tests/encounter_sequence_smoke_test.gd`

## Work

1. WAVE는 WARNING 전에 `wait_for_clear`를 존중한다. `clear_timeout` > 0이면 클리어와 타임아웃 중 먼저 온 쪽으로 진행하고, `clear_min_wait`로 최소 호흡을 보장한다.
2. `drone_swarm_wave` 편대 간격을 줄여 WAVE 구간이 NORMAL보다 촘촘하게 느껴지게 한다.
3. 기본 시퀀스 `b` 스텝에 timeout·min_wait·post_delay(5.0~5.5) 수치를 넣고 smoke로 검증한다.

## Verification

- [x] `.\tools\run-godot.cmd --headless --script res://tests/encounter_sequence_smoke_test.gd` → PASS
