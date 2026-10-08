# Encounter 카탈로그

`main_encounter_pool.tres` 등록분. weight = `60 / √difficulty` (min_threat 미만이면 0).

Threat 1 후보 합 weight ≈115.4 · Threat 2 ≈206.7 · Threat 3 ≈321.7.

## 풀 등록

| Encounter | difficulty | min_threat | weight | 진형 | 멤버 요지 | 이동·해제 요지 |
|-----------|----------:|-----------:|-------:|------|-----------|----------------|
| `drone_formation` | 11 | 1 | ≈18.11 | [Horizontal](../formations/horizontal.md) | [Drone](../enemies/drone.md)×5 | 대각 유지 (`formation_drone_diagonal`) |
| `drone_zigzag_mirrored` | 6 | 1 | ≈24.49 | [V5](../formations/v5.md) | Drone | zigzag · mirrored · 점유 폭 기준 VisibleRect 반사 |
| `drone_spread_formation` | 12 | 1 | ≈17.32 | [Horizontal](../formations/horizontal.md) | [산탄 드론](../enemies/drone.md#변종-enemiesvariants)×5 | 대각 유지 (`formation_drone_diagonal`) |
| `drone_slow_zigzag` | 10 | 2 | ≈18.97 | [V5](../formations/v5.md) | [느린탄 드론](../enemies/drone.md#변종-enemiesvariants)×5 | zigzag · mirrored |
| `drone_halt_formation` | 14 | 2 | ≈16.04 | [Horizontal](../formations/horizontal.md) | [정지탄 드론](../enemies/drone.md#변종-enemiesvariants)×5 | 대각 유지 |
| `striker_drone_diamond_5` | 7 | 1 | ≈22.68 | [Diamond5](../formations/diamond-5.md) | [Striker](../enemies/striker.md) Slot0 + Drone×4 | 1/3 하강 → 해제 → scatter / charge |
| `awl_formation` | 12 | 1 | ≈17.32 | [V3](../formations/v3.md) | [Awl](../enemies/awl.md)×3 | 하강 유지 → 분리 차징 돌진 |
| `striker_drone_diamond_13` | 15 | 1 | ≈15.49 | [Diamond13](../formations/diamond-13.md) | Striker + Drone×12 | 5기와 동일 진입·산개 |
| `bomb_pair` | 9 | 2 | 20 | [BombPair](../formations/bomb-pair.md) | [Bomb](../enemies/bomb.md)×2 (160px 간격) | 즉시 해제 → 각자 `bomb_straight_down` 40px/s |
| `interceptor_pair` | 12 | 2 | ≈17.32 | [Pair](../formations/interceptor-pair.md) | [Interceptor](../enemies/interceptor.md)×2 | ForwardAttackRun 대각 · 경고 0.9s |
| `tanker_guard_sniper` | 10 | 2 | ≈18.97 | (가드 layout) | [Tanker](../enemies/tanker.md) 전방 + [Sniper](../enemies/sniper.md) 후방 | y=48 체공 정지 · Sniper만 사격 |
| `caster_single` | 7 | 3 | ≈22.68 | [Single](../formations/single.md) | [Caster](../enemies/caster.md) | 즉시 해제 → 상단 패트롤 · 원형 탄막 |
| `v7_drone_down` | 7 | 3 | ≈22.68 | [V7](../formations/v7.md) | Drone | midmap 하강 → 외향 산개 ×2.5 |
| `x9_drone_down` | 9 | 3 | 20 | [X9](../formations/x9.md) | Drone | midmap 하강 → 외향 산개 |
| `x9_caster_drone_orbit` | 15 | 3 | ≈15.49 | [X9](../formations/x9.md) | Caster 중심 + Drone×8 | y=48 패트롤 · OrbitBehavior |
| `interceptor_trio` | 18 | 3 | ≈14.14 | [V3](../formations/v3.md) | Interceptor×3 | pair와 동일 ForwardAttackRun |
| `courier_single` | 9 | 3 | 20 | [Single](../formations/single.md) | [Courier](../enemies/courier.md) | 먼 쪽 위 가장자리(`TOP_FAR_SIDE`) · 즉시 해제 → 플레이어 옆을 스치는 큰 호(170px/s) · 스치는 순간 즉시 점화 Bomb 투하 → 같은 방향으로 휘며 300px/s 이탈 |

## 풀 밖 (게이트 / 대체 / 랩)

| Encounter | 비고 |
|-----------|------|
| `threat_elite_single` / `threat_elite_awl` | 시퀀스 ELITE 관문 (일반 풀과 분리) — [elite-fighter](../elites/elite-fighter.md) · [run-pacing](../run-pacing.md) |
| `boss_carrier` | 시퀀스 BOSS 관문 `d`. 껍데기 Enemy 1기가 항모 본체를 전장에 띄운다 — [거대 항모](../bosses/carrier.md). `boss_wall`은 Lab 전용 |
| `drone_triangle_formation` / `drone_zigzag_formation` | 구절 `L` 교재 A(`lesson_aim_a`)에서 사용. 일반 풀 미등록이어도 실제 전투 콘텐츠다 — [런 페이싱 · 구절 작곡](../run-pacing.md#구절-작곡-현재-기본-시퀀스) |
| `sniper_reinforcement` | 탱커 생존 시 `tanker_guard_sniper` 대체 |
| `elite_escort_drone_pair` | 적 증강 「엘리트 호위대」 선택 후 엘리트 관문마다 함께 스폰되는 Drone 2기 — [오그먼트](../augments.md#적-풀) |
| `bomb_drone_diamond` | 레거시 · 풀·구절 미등록. Diamond5 Slot0 Bomb + Drone×4, 무한 호밍 접근 · Bomb 상실 시 해제(`ANCHOR_LOST`) → Drone `individual_scatter` — [Bomb](../enemies/bomb.md#레거시-bomb_drone_diamond의-편대-해제-anchor_lost) |
| `v3`/`v5`/`v9`/`inverted_*`/`x5_drone_down`, `striker_single`, `tanker_bomb_*` | 테스트·레거시 · **MainEncounterPool 미등록** |

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
