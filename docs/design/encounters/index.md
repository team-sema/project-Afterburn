# Encounter (조합)

**실제 스폰 단위**다. 적 유닛과 진형 layout을 슬롯에 묶고, 편대/개별 이동·해제 규칙을 붙인 것이 `EncounterPreset`이다.

```text
enemies/<type>     +  formations/<layout>  +  MovementSequence
        \                    |                    /
         \                   v                   /
          ──── EncounterPreset (이 층) ────
                         |
                         v
              EncounterPoolEntry (min_threat)
                         |
                         v
              EnemyGenerator 타이머 (run-pacing)
```

코드:

| 리소스 | 경로 |
|--------|------|
| Preset | `resources/encounters/presets/<id>.tres` |
| Pool | `resources/encounters/pools/main_encounter_pool.tres` |
| 스크립트 | `EncounterPreset` · `EncounterMember` · `EncounterPoolEntry` |

## Preset이 담는 것

| 필드 | 의미 | 문서 |
|------|------|------|
| `encounter_id` | slug | catalog 행 |
| `difficulty` | weight = `60 / √difficulty` | catalog |
| `formation_layout_scene` | 슬롯 기하 | → formations |
| `members[]` | 슬롯별 적 씬 | → enemies |
| `formation_movement_sequence` | 편대 이동 | catalog / 상세 |
| `formation_break_*` + `individual_*` | 해제 후 산개 | catalog |
| `spawn_*` / `start_delay` | 스폰 앵커·경고 | catalog |

## 읽는 순서

1. [카탈로그](catalog.md) — 풀에 뭐가 있나
2. 궁금한 Encounter 행의 진형·적 링크
3. [런·페이싱](../run-pacing.md) — 얼마나 자주·Threat 게이트

## 작성 규칙

- 유닛 HP/사격 수치를 여기 다시 쓰지 않는다 → enemies 링크
- 슬롯 오프셋을 여기 다시 쓰지 않는다 → formations 링크
- 신규 조합 = preset `.tres` + catalog 한 줄 (+ 필요 시 상세 MD)
