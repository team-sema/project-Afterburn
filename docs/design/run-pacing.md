# 런 · 페이싱

## 기획 의도

일반 Encounter 구간과 엘리트 관문을 번갈아 배치해 전투 압력과 강화 선택의 리듬을 만든다.

## 확정된 현재 동작

한 판의 **시간·Threat·등장 순서·엘리트 게이트**. 개별 적/진형/조합 수치는 하위 문서로.

## 플레이어 오퍼

- 적 처치 → XP → 임계 충족 후 **`C`** 로 플레이어 오그먼트 오픈
- 상세 풀·리롤: [오그먼트](augments.md)

## 등장 시퀀스 (`EncounterDirector`)

무엇이 언제 나오는지는 **데이터 시퀀스** `resources/encounter_sequences/main_encounter_sequence.tres` 가 정한다. `gameplay.tscn`의 `EncounterDirector`가 런 시작과 함께 재생하며, 그 순간 `EnemyGenerator` 타이머와 `AugmentProgressionController` 60초 엘리트 타이머를 **꺼서 대체**한다 (테스트처럼 Director가 시작하지 않으면 두 타이머는 예전 그대로 동작).

- **Phase**: 공백으로 나눈 토큰 패턴 (`"a a a b a a c"`) + `repeat_count`. 순서대로 실행.
- **Step(토큰)**: 종류 `NORMAL` / `WAVE` / `ELITE` / `BOSS` + `post_delay_min~max`. 시퀀스 공용(`shared_steps`) 또는 Phase 로컬(`steps`, 같은 토큰이면 우선).
- **다음 스텝까지 간격**: 매 스텝 `[post_delay_min, post_delay_max]` 균등 랜덤. 기준 시점 — NORMAL: 스폰 순간 · WAVE: 마지막 편대 스폰 순간 · ELITE/BOSS: 게이트가 닫힌 순간. NORMAL끼리·WAVE 종료 후는 앞 스텝 적이 살아 있어도 기다리지 않는다.
- 마지막 Phase가 끝나면 `on_complete` — `REPEAT_LAST_PHASE`(기본) 또는 `STOP`.

| 종류 | 무엇을 | 후보 선택 |
|---|---|---|
| `NORMAL` | 편대 1개 | `encounter_presets` 지정 시 균등 랜덤(직전 id 회피, **Threat 무시**) · 비었으면 `encounter_pool.choose(현재 Threat)` (weight·min_threat·직전 2 id 제외 그대로) |
| `WAVE` | `EncounterWave` 의 `encounter_presets`(프리셋 참조 배열, 정본)를 **순서대로**, 편대 사이 `interval_min~max` 랜덤. 옛 `encounter_preset_paths` 경로 목록은 비어 있지 않은 쪽만 폴백으로 읽는다 | `waves`(대안 목록)가 있으면 그중 균등 랜덤(직전에 재생한 wave 회피), 없으면 `wave` 하나 |
| `ELITE` | 아래 엘리트 게이트를 연다 | `elite_preset` 지정 시 그 preset, 비우면 엘리트 로테이션 |
| `BOSS` | 엘리트 게이트와 같은 흐름 + `is_boss` (엘리트 HP 공식 미적용) | `boss_preset` 비어 있으면 경고 후 **건너뜀** |

`WAVE`/`ELITE`/`BOSS`는 `wait_for_clear`(기본 true)면 WARNING·게이트 전에 Director가 추적 중인 편대가 비울 때까지 기다린다. `clear_timeout` > 0이면 **클리어 또는 타임아웃 중 먼저** 온 쪽으로 진행하고, `clear_min_wait`가 있으면 그 대기 시작부터 최소 그 초만큼은 쉰 뒤 진행한다 (빨리 클리어해도 WAVE 호흡을 남김). `clear_timeout` 0은 클리어만 본다(무한 대기). 대기 시간은 게임플레이 시간(프로세스 델타)으로 계산하므로 오그먼트 선택·탄소거 등 트리 일시정지 동안은 흐르지 않는다.

WAVE·ELITE·BOSS 스텝은 스폰/게이트 직전에 맵 중앙에 `WARNING` 텍스트가 점멸한다 (NORMAL은 없음).

## 구절 작곡 (현재 기본 시퀀스)

등장은 **구절**(편대 3개짜리 WAVE) 단위로 쓴다. 원칙은 네 가지다.

1. **한 구절에 새 것 하나.** 구절마다 가르치는 회피 기술이 하나이고, 그 기술은 적 기획서의 「플레이어가 고민할 점」에서 온다.
2. **같은 교훈, 다른 교재.** 구절마다 대안 wave를 둘 두고(`waves`) 런마다 하나를 뽑는다. 순서는 달라도 배우는 기술의 순서는 같다.
3. **구절은 긴장 → 해소.** WAVE 뒤에 `clear_min_wait`로 숨을 주고, 구절 사이에는 풀 추첨 `a`를 하나 이상 둬 두 구절이 붙지 않게 한다.
4. **랜덤의 폭은 단계별로.** 교습 Phase는 "대안 둘 중 하나", 혼합 Phase는 풀 전체다. 후반은 카오스를 허용한다.

**토큰**

| 토큰 | 종류 | 내용 | post_delay · clear |
|---|---|---|---|
| `a` | NORMAL | `MainEncounterPool` 랜덤 (Threat 가중) | 2.8 ~ 3.1초 |
| `L` `H` `W` `S` `B` `G` `F` `D` | WAVE | 아래 구절. 각 토큰은 대안 wave A/B 중 하나 | 3.0 ~ 3.4초 · clear_timeout 6.0 · clear_min_wait Phase 1 3.0 / 2 2.5 / 3 2.0 |
| `c` | ELITE | 엘리트 로테이션 · wait_for_clear (timeout 없음) | 2.8 ~ 3.1초 |
| `d` | BOSS | `boss_wall` | 2.8 ~ 3.1초 |

**구절** (`resources/encounter_sequences/waves/lesson_*.tres`, 프리셋 참조 배열로 저장. 편대 간격은 Phase 1 3.5~4.0초 · 2 3.0~3.3초 · 3 2.8~3.0초)

| 토큰 | 교훈 | 교재 A | 교재 B |
|---|---|---|---|
| `L` 조준탄 | 쏘면 비킨다 | drone_formation → triangle → zigzag | 산탄 드론 → drone_formation → 산탄 드론 |
| `H` 핵 | 호위 뚫고 핵부터 칠지 | Striker 5 → zigzag_mirrored → Striker 13 | Striker 5 → 산탄 드론 → Striker 13 |
| `W` 몸 | 차징 읽기와 탄 피하기의 차이 | Awl → zigzag_mirrored → Awl | Awl → drone_formation → Awl |
| `S` 측면 | 가장자리 경고에 시선 옮기기 | Interceptor pair → drone_formation → pair | Interceptor pair → 산탄 드론 → pair |
| `B` 공간 | 거리 관리 | Bomb diamond → Awl → Bomb diamond | Bomb diamond → 느린탄 드론 → Bomb diamond |
| `G` 가드 | 조준선 피하기 + 앞 막은 적 뒤 노리기 | Tanker+Sniper → Interceptor pair → Tanker+Sniper | 정지탄 드론 → Tanker+Sniper → 정지탄 드론 |
| `F` 통로 | 빈 통로 찾기 | Caster → V7 하강 → X9 orbit | 느린탄 드론 → Caster → X9 orbit |
| `D` 하강 | 산개 예측 | X9 하강 → Interceptor trio → V7 하강 | V7 하강 → 정지탄 드론 → X9 하강 |

구절 안의 편대는 그 Phase 시작 시점의 Threat에서 쓸 수 있는 것만 넣는다(Phase 1은 Threat 1 콘텐츠만). `tests/run_phrase_sequence_test.gd`가 이를 검사한다.

**Phase**

| Phase | 시작 Threat | 패턴 | 의도 |
|---|---|---|---|
| `lesson_1` 교습 | 1 | `L a H a W a c` | 모든 런이 같은 세 교훈으로 시작. 첫 엘리트(Fighter) |
| `lesson_2` 압박 | 2 | `S a B a G a a c` | 측면·공간·가드. 복습 2개. 둘째 엘리트(Awl) |
| `lesson_3` 장판 | 3 | `F a D a a a c d` | 통로·하강. 복습 3개. 엘리트 → 보스 |
| `mix` 혼합 (반복) | 4+ | `a a S a a F a a c a a B a a G a a D a a d` | 배운 구절을 풀 추첨 사이에 섞음. `REPEAT_LAST_PHASE` |

Phase가 바뀔 때마다 HUD의 STAGE가 +1 된다. 개발자는 `.tres`의 패턴 문자열·토큰·wave 목록만 고쳐 시나리오를 바꾼다. 현행 규칙·완료 조건은 이 문서를 따른다.

## 일반 Encounter 스폰 (타이머 — Director 미사용 시)

- 주기: **2.8초 + 0~0.3초** 지터 (`EnemyGenerator`, `automatic_spawning_enabled`)
- 선택: `MainEncounterPool` weighted random 1회
- 직전 **2개** Encounter id는 후보에서 제외 (대안이 있을 때)
- weight · min_threat · 등록 목록: [Encounter 카탈로그](encounters/catalog.md)

## Threat · 엘리트 게이트

우선순위(겹칠 때): `boss > elite > augment offer > normal encounter`.

| 단계 | 동작 |
|------|------|
| 게이트 오픈 (`ELITE` 스텝, 또는 Director 미사용 시 60초 타이머) | 엘리트 로테이션으로 1기 (`ThreatEliteController`). 스텝의 `elite_preset`이 있으면 그 preset. 적 증강 「엘리트 호위대」가 있으면 호위 Encounter를 함께 스폰 |
| 엘리트 전투 중 | 일반 Encounter 스폰 **정지** (시퀀스도 대기) · 기존 일반 적 유지 |
| 엘리트 처치 | 전투 정지 → 적탄을 XP로 변환 → 화면의 모든 XP 강제 회수 |
| XP 회수 완료 | Threat **+1** → 적 증강 3지선다 |
| 오퍼 완료 | 게이트 닫힘 → 시퀀스 다음 스텝 (타이머 모드면 일반 스폰·다음 Threat 타이머 재개) |
| 전투·오퍼 중 | Threat 시간 **누적 안 함** (연속 엘리트 방지) |

첫 엘리트: Threat **2** 사격형(Fighter). Threat **3** 돌격형(Awl). Threat 4부터는 Fighter·Awl·Bomb·Caster 중 직전 엘리트를 제외하고 무작위로 고른다. 여기서 Threat는 처치 후 도달할 관문 목표값이다. 로테이션·공통 HP 공식은 [엘리트](elites/index.md) 정본.

탄소거 보상 중에는 전투 전체와 플레이어 오그먼트 `C` 입력을 잠근다. 적탄 1발은 XP 1로 변환되며, 기존 XP와 엘리트 확정 드롭까지 실제로 수집된 뒤에만 적 오그먼트 오퍼가 열린다. BOSS 관문도 같은 처치 정산(탄소거·XP 회수·Threat 상승·적 오퍼)을 거친다.

## Threat HUD

- **시퀀스 모드** (`EncounterDirector` 실행 중): `STAGE MM` + 바 = 현재 스테이지(패턴 1회) 안 스텝 진행도. 패턴이 반복될 때마다 STAGE +1. 엘리트 게이트 중에는 `STAGE MM   ELITE ENGAGED`.
- **타이머 모드** (Director 미사용): 기존 `MM:SS` 카운트다운 (Threat 숫자는 HUD에 표시하지 않음).

## Threat별 로스터 요지

- **Threat 1:** Drone·Striker 호위·Awl 등 (Bomb·Interceptor pair 제외)
- **Threat 2+:** `tanker_guard_sniper` · `bomb_drone_diamond` · `interceptor_pair`
- **Threat 3+:** Caster · V7/X9 하강 · X9 orbit · Interceptor trio

## 관련

- [적](enemies/index.md) · [진형](formations/index.md) · [Encounter](encounters/index.md)
- 보스 콘텐츠의 미결정 사항: [미결정·확장 후보](gaps.md)

## 완료 조건·검증

- 엘리트 전투 중 일반 Encounter 생성이 멈추고 기존 일반 적은 유지된다.
- 처치 보상 정산 후 Threat 상승·적 오퍼·다음 구간 순서가 지켜진다.
- 엘리트·오퍼 중 다음 관문 시간이 누적되지 않는다.
- WAVE는 WARNING 전에 선행 편대 클리어(또는 `clear_timeout`)와 `clear_min_wait` 호흡을 거친다.
- 클리어 대기 중 일시정지된 시간은 `clear_min_wait`에서 차감되지 않는다.
- 교습 Phase 1~3은 구절 → 풀 추첨 → 구절 순서를 지키고 두 구절이 붙지 않으며, 각 구절은 대안 wave 둘 중 하나를 재생한다. 구절 편대는 그 Phase의 Threat에서 쓸 수 있는 것만 쓴다.

검증 참고: `tests/run_phrase_sequence_test.gd` · `tests/threat_elite_progression_smoke_test.gd` · `tests/encounter_sequence_smoke_test.gd`. Godot 실행은 `tools/run-godot.cmd`를 사용한다.
