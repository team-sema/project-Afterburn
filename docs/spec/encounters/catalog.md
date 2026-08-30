# Encounter 카탈로그

`main_encounter_pool.tres` 등록분. weight = `60 / √difficulty` (min_threat 미만이면 0).

Threat 1 후보 합 weight ≈135.4 · Threat 2 ≈154.4 · Threat 3 ≈249.4.

## 풀 등록

| Encounter | difficulty | min_threat | weight | 진형 | 멤버 요지 | 이동·해제 요지 |
|-----------|----------:|-----------:|-------:|------|-----------|----------------|
| `drone_formation` | 11 | 1 | ≈18.11 | [Horizontal](#formations/horizontal) | [Drone](#enemies/drone)×5 | 대각 유지 (`formation_drone_diagonal`) |
| `drone_zigzag_mirrored` | 6 | 1 | ≈24.49 | V5 | Drone | zigzag · mirrored · MovementArea bounce |
| `striker_drone_diamond_5` | 7 | 1 | ≈22.68 | [Diamond5](#formations/diamond-5) | [Striker](#enemies/striker) Slot0 + Drone×4 | 1/3 하강 → 해제 → scatter / charge |
| `awl_formation` | 12 | 1 | ≈17.32 | [V3](#formations/v3) | [Awl](#enemies/awl)×3 | 하강 유지 → 분리 차징 돌진 |
| `striker_drone_diamond_13` | 15 | 1 | ≈15.49 | [Diamond13](#formations/diamond-13) | Striker + Drone×12 | 5기와 동일 진입·산개 |
| `bomb_drone_diamond` | 9 | 1 | 20 | [Diamond5](#formations/diamond-5) | [Bomb](#enemies/bomb) center + Drone×4 | 호밍 접근 · 퓨즈 시 정지 |
| `interceptor_pair` | 12 | 1 | ≈17.32 | [Pair](#formations/interceptor-pair) | [Interceptor](#enemies/interceptor)×2 | ForwardAttackRun 대각 · 경고 0.9s |
| `tanker_guard_sniper` | 10 | 2 | ≈18.97 | (가드 layout) | Tanker 전방 + [Sniper](#enemies/sniper) 후방 | y=48 체공 정지 · Sniper만 사격 |
| `caster_single` | 7 | 3 | ≈22.68 | [Single](#formations/single) | [Caster](#enemies/caster) | 즉시 해제 → 상단 패트롤 · 원형 탄막 |
| `v7_drone_down` | 7 | 3 | ≈22.68 | V7 | Drone | midmap 하강 → 외향 산개 ×2.5 |
| `x9_drone_down` | 9 | 3 | 20 | [X9](#formations/x9) | Drone | midmap 하강 → 외향 산개 |
| `x9_caster_drone_orbit` | 15 | 3 | ≈15.49 | [X9](#formations/x9) | Caster 중심 + Drone×8 | y=48 패트롤 · OrbitBehavior |
| `interceptor_trio` | 18 | 3 | ≈14.14 | [V3](#formations/v3) | Interceptor×3 | pair와 동일 ForwardAttackRun |

## 풀 밖 (게이트 / 대체 / 랩)

| Encounter | 비고 |
|-----------|------|
| `threat_elite_single` | 60초 엘리트 — [elite-fighter](#enemies/elite-fighter) · [run-pacing](#run-pacing) |
| `sniper_reinforcement` | 탱커 생존 시 `tanker_guard_sniper` 대체 |
| `v3`/`v5`/`v9`/`inverted_*`/`x5_drone_down`, `drone_triangle_formation`, `striker_single`, `bomb_single`, `tanker_bomb_*` | 테스트·레거시 · **MainEncounterPool 미등록** |

## 조합 예시: `striker_drone_diamond_5`

| 층 | 값 |
|----|-----|
| 진형 | Diamond5 |
| 멤버 | Slot0 Striker · Slot1–4 Drone |
| 편대 이동 | `formation_entry_third` (40px/s → 뷰포트 1/3) |
| 해제 | `SEQUENCE_FINISHED` |
| 개별 | Drone `individual_scatter_2_5`(100px/s) · Striker `individual_striker_charge_2_5` |
| difficulty | 7 · min_threat 1 |

코드: `resources/encounters/presets/striker_drone_diamond_5.tres`
