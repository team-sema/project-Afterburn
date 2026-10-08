# Encounter (조합)

**실제 스폰 단위**다. 적 유닛과 진형 layout을 슬롯에 묶고, 편대/개별 이동·해제 규칙을 붙인 것이 `EncounterPreset`이다.

```text
enemies/<type>     +  formations/<layout>  +  MovementSequence
        \                    |                    /
         \                   v                   /
          ──── EncounterPreset (이 층) ────
                         |
                         v
              EncounterPoolEntry (min_threat)   또는   Step에 직접 지정 / EncounterWave
                         |
                         v
              EncounterSequence 토큰 패턴 → EncounterDirector (run-pacing)
```

코드:

| 리소스 | 경로 |
|--------|------|
| Preset | `resources/encounters/presets/<id>.tres` |
| Pool | `resources/encounters/pools/main_encounter_pool.tres` |
| 시퀀스 | `resources/encounter_sequences/main_encounter_sequence.tres` · 구절 `waves/lesson_*.tres` |
| 스크립트 | `EncounterPreset` · `EncounterMember` · `EncounterPoolEntry` · `EncounterSequence` · `EncounterSequencePhase` · `EncounterSequenceStep` · `EncounterWave` |

## Preset이 담는 것

| 필드 | 의미 | 문서 |
|------|------|------|
| `encounter_id` | slug | catalog 행 |
| `difficulty` | weight = `60 / √difficulty` | catalog |
| `formation_layout_scene` | 슬롯 기하 | → formations |
| `members[]` | 슬롯별 적 씬 | → enemies |
| `formation_movement_sequence` | 편대 이동 | catalog / 상세 |
| `formation_break_*` + `individual_*` | 해제 후 산개 | catalog |
| `formation_anchor_slot_index` | `ANCHOR_LOST` 해제의 앵커 슬롯 | 아래 |
| `spawn_*` / `start_delay` | 스폰 앵커·경고 | catalog |

## 편대 해제 조건 (`formation_break_condition`)

| 값 | 해제 시점 |
|----|-----------|
| `NEVER` | 해제하지 않는다. 편대 이동이 끝없는 호밍·패트롤이면 멤버가 화면에 남는다 |
| `SEQUENCE_FINISHED` | 편대 이동 시퀀스 완료 |
| `ELAPSED_TIME` | 편대 시작 후 `formation_break_delay`초 |
| `ANCHOR_LOST` | `formation_anchor_slot_index` 멤버가 씬 트리에서 빠질 때(처치·자폭·화면 밖 해제). 앵커가 자기 행동으로 detach한 것만으로는 해제하지 않고, detach 뒤에 사라질 때 해제한다 |

`NEVER`가 아니면 모든 멤버에 개별 이동(`individual_movement_sequence` 또는 멤버 override)이 있어야 한다. `ANCHOR_LOST`는 앵커 슬롯에 멤버가 있어야 한다(`EncounterPreset.validate`).

## 읽는 순서

1. [카탈로그](catalog.md) — 풀에 뭐가 있나
2. 궁금한 Encounter 행의 진형·적 링크
3. [런·페이싱](../run-pacing.md) — 어떤 순서·간격으로(시퀀스)·Threat 게이트

## 작성 규칙

- 유닛 HP/사격 수치를 여기 다시 쓰지 않는다 → enemies 링크
- 슬롯 오프셋을 여기 다시 쓰지 않는다 → formations 링크
- 신규 조합 = preset `.tres` + catalog 한 줄 (+ 필요 시 상세 MD)
