# 런 · 페이싱

## 기획 의도

일반 Encounter 구간과 엘리트 관문을 번갈아 배치해 전투 압력과 강화 선택의 리듬을 만든다.

## 확정된 현재 동작

한 판의 **시간·Threat·등장 순서·엘리트 게이트**. 개별 적/진형/조합 수치는 하위 문서로.

## 플레이어 오퍼

- 적 처치 → XP → 임계 충족 후 **`C`** 로 플레이어 오그먼트 오픈
- 상세 풀·리롤: [오그먼트](augments.md)

## 등장 시퀀스 (`EncounterDirector`)

무엇이 언제 나오는지는 **데이터 시퀀스** `resources/encounter_sequences/main_encounter_sequence.tres` 가 정한다. `gameplay.tscn`의 `EncounterDirector`가 출격 시퀀스(2.6초, [씬 흐름](scene-flow.md#런-시작--출격-시퀀스-effectslaunch_sequencegd-launchsequence))가 끝나는 순간 재생을 시작하며, 그 순간 `EnemyGenerator` 타이머와 `AugmentProgressionController` 60초 엘리트 타이머를 **꺼서 대체**한다 (테스트처럼 Director가 시작하지 않으면 두 타이머는 예전 그대로 동작).

- **Phase**: 공백으로 나눈 토큰 패턴 (`"a a a b a a c"`) + `repeat_count`. 순서대로 실행.
- **Step(토큰)**: 종류 `NORMAL` / `WAVE` / `ELITE` / `BOSS` + `post_delay_min~max` + `handoff_remaining`. 시퀀스 공용(`shared_steps`) 또는 Phase 로컬(`steps`, 같은 토큰이면 우선).
- **다음 스텝까지 간격 (인계)**: 기준 시점 — NORMAL: 마지막 스폰 순간 · WAVE: 마지막 편대 스폰 순간 · ELITE/BOSS: 게이트가 닫힌 순간. `handoff_remaining` ≥ 1이면 **인계 규칙**: `post_delay_min`은 반드시 쉬고, 그 뒤로는 이 스텝이 낸 편대들의 살아 있는 적 합계가 `handoff_remaining` 이하로 줄어드는 순간 바로 다음 스텝으로 간다. 그래도 안 줄면 `post_delay_max`에 간다. 즉 min은 바닥, max는 천장이며 화면이 비기 전에 다음 편대가 들어온다. `handoff_remaining` 0이면 옛 방식대로 `[min, max]` 균등 랜덤이고 적 수를 보지 않는다 (게이트 토큰은 이쪽).
- 마지막 Phase가 끝나면 `on_complete` — `REPEAT_LAST_PHASE`(기본) 또는 `STOP`.

| 종류 | 무엇을 | 후보 선택 |
|---|---|---|
| `NORMAL` | 편대 `encounter_count`개 (기본 1). 2 이상이면 `encounter_gap`초 간격으로 연달아 내어 겹친다 | `encounter_presets` 지정 시 균등 랜덤(직전 id 회피, **Threat 무시**) · 비었으면 `encounter_pool.choose(현재 Threat)` (weight·min_threat·직전 2 id 제외 그대로) |
| `WAVE` | `EncounterWave` 의 `encounter_presets`(프리셋 참조 배열, 정본)를 **순서대로**. 편대 사이는 wave의 `handoff_remaining`이 1 이상이면 인계 규칙(`interval_min` 바닥 · 이 wave가 지금까지 낸 편대의 잔존 합계 ≤ `handoff_remaining`이면 즉시 · `interval_max` 천장), 0이면 `interval_min~max` 랜덤. 옛 `encounter_preset_paths` 경로 목록은 비어 있지 않은 쪽만 폴백으로 읽는다 | `waves`(대안 목록)가 있으면 그중 균등 랜덤(직전에 재생한 wave 회피), 없으면 `wave` 하나 |
| `ELITE` | 아래 엘리트 게이트를 연다 | `elite_preset` 지정 시 그 preset, 비우면 엘리트 로테이션 |
| `BOSS` | 엘리트 게이트와 같은 흐름 + `is_boss` (엘리트 HP 공식 미적용) | `boss_preset` 비어 있으면 경고 없이 **건너뜀** |

`WAVE`/`ELITE`/`BOSS`는 `wait_for_clear`(기본 true)면 스폰·게이트 전에 Director가 추적 중인 편대의 잔존 합계가 스텝의 `handoff_remaining` 이하가 될 때까지 기다린다 (0이면 전원 클리어). `clear_timeout` > 0이면 **클리어 또는 타임아웃 중 먼저** 온 쪽으로 진행하고, `clear_min_wait`가 있으면 그 대기 시작부터 최소 그 초만큼은 쉰 뒤 진행한다 (빨리 클리어해도 WAVE 호흡을 남김). `clear_timeout` 0은 클리어만 본다(무한 대기). 대기 시간은 게임플레이 시간(프로세스 델타)으로 계산하므로 오그먼트 선택 등 트리 일시정지 동안은 흐르지 않는다. 탄소거 보상은 트리를 멈추지 않으므로 그동안에도 흐른다.

### 관문 경고 (`EncounterStepWarning`)

ELITE·BOSS 게이트 직전에만 `step_warning_duration`(기본 **1.6초**) 동안 맵 중앙에 관문 경고가 뜬다. WAVE는 경고 없이 바로 들어온다 (구절은 흐름의 일부이지 사건이 아니다). 경고의 목적은 "큰 것이 온다"를 한 번에 읽히게 하는 것이다.

- 종류별 문구·색: ELITE `ELITE INBOUND` 주황빨강 · BOSS `BOSS INBOUND` 자홍. 아래 작은 글자 `CLEAR THE LANE`.
- 화면 폭 전체의 반투명 검은 띠(높이 56px)가 중앙에서 좌우로 0.25초에 펼쳐지고, 띠 위아래로 사선 해저드 스트라이프가 흐른다. 화면 테두리도 같은 색으로 맥동한다.
- 밝기는 초당 2.5회 맥동하고 마지막 0.3초에 사라진다.
- `sounds/warning_sound.wav`(2음 클락슨, SFX 버스)를 경고 시작에 1회 재생한다.
- Interceptor 가장자리 화살표(`EntryWarningComponent`)는 별개이며 그대로다.

## 구절 작곡 (현재 기본 시퀀스)

등장은 **구절**(편대 3개짜리 WAVE) 단위로 쓴다. 원칙은 네 가지다.

1. **한 구절에 새 것 하나.** 구절마다 가르치는 회피 기술이 하나이고, 그 기술은 적 기획서의 「플레이어가 고민할 점」에서 온다.
2. **같은 교훈, 다른 교재.** 구절마다 대안 wave를 둘 두고(`waves`) 런마다 하나를 뽑는다. 순서는 달라도 배우는 기술의 순서는 같다.
3. **구절은 긴장 → 해소.** WAVE 뒤에 `clear_min_wait`로 짧은 숨을 주고, 구절 사이에는 풀 추첨 `a`/`A`를 하나 이상 둬 두 구절이 붙지 않게 한다.
4. **랜덤의 폭은 단계별로.** 교습 Phase는 "대안 둘 중 하나", 혼합 Phase는 풀 전체다. 후반은 카오스를 허용한다.
5. **화면은 비지 않는다.** 편대 사이·스텝 사이 간격은 전부 인계 규칙(`handoff_remaining` 2)이다. 앞 편대가 2기 이하로 줄면 바닥 시간만 채우고 다음 편대가 들어온다. 잘 지울수록 빨라지고, 못 지우면 천장에서 들어온다. 간격 수치는 그래서 "바닥 ~ 천장"이다.

**토큰**

| 토큰 | 종류 | 내용 | post_delay(바닥 ~ 천장) · clear |
|---|---|---|---|
| `a` | NORMAL | `MainEncounterPool` 랜덤 (Threat 가중) 1편대 | 1.6 ~ 3.0초 · handoff 2 |
| `A` | NORMAL | 같은 풀에서 **2편대**를 1.2초 간격으로 겹쳐 냄 (Phase 2+) | 1.6 ~ 3.0초 · handoff 2 |
| `L` `H` `W` `S` `B` `G` `F` `D` | WAVE | 아래 구절. 각 토큰은 대안 wave A/B 중 하나 | 1.5 ~ 3.0초 · handoff 2 · clear_timeout 6.0 · clear_min_wait Phase 1 1.2 / 2 1.0 / 3 0.8 |
| `c` | ELITE | 엘리트 로테이션 · wait_for_clear (timeout 없음, 전원 클리어) | 2.8 ~ 3.1초 랜덤 (handoff 0) |
| `d` | BOSS | `boss_carrier` ([거대 항모](bosses/carrier.md)) | 2.8 ~ 3.1초 랜덤 (handoff 0) |

**구절** (`resources/encounter_sequences/waves/lesson_*.tres`, 프리셋 참조 배열로 저장. 편대 간격은 인계 규칙(handoff 2)으로 바닥 ~ 천장: Phase 1 1.2 ~ 3.0초 · 2 1.0 ~ 2.6초 · 3 0.8 ~ 2.4초)

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
| `lesson_2` 압박 | 2 | `S A B A G A a c` | 측면·공간·가드. 풀 추첨은 2편대 겹침 `A`. 둘째 엘리트(Awl) |
| `lesson_3` 장판 | 3 | `F A D A a A c d` | 통로·하강. 복습 3슬롯. 엘리트 → 보스 |
| `mix` 혼합 (반복) | 4+ | `A a S A a F A a c A a B A a G A a D A a d` | 배운 구절을 풀 추첨(겹침 2 + 단독 1) 사이에 섞음. `REPEAT_LAST_PHASE` |

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
| 엘리트 처치 | 게임은 멈추지 않음 → 화면 안 적탄만 XP로 변환(밖은 소거) → 모든 XP 강제 회수(0.6초 도착 · 1.0초 상한) |
| XP 회수 완료 | Threat **+1** → 적 증강 3지선다 |
| 오퍼 완료 | 게이트 닫힘 → 시퀀스 다음 스텝 (타이머 모드면 일반 스폰·다음 Threat 타이머 재개) |
| 전투·오퍼 중 | Threat 시간 **누적 안 함** (연속 엘리트 방지) |

첫 엘리트: Threat **2** 사격형(Fighter). Threat **3** 돌격형(Awl). Threat 4부터는 Fighter·Awl·Bomb·Caster 중 직전 엘리트를 제외하고 무작위로 고른다. 여기서 Threat는 처치 후 도달할 관문 목표값이다. 로테이션·공통 HP 공식은 [엘리트](elites/index.md) 정본.

탄소거 보상은 게임을 멈추지 않는다. 처치 순간 정지되는 느낌을 없애기 위해 함선 이동·사격, 남은 일반 적과 그 사격, 수동 일시정지는 그대로 동작하고, 보상이 끝날 때까지 플레이어 오그먼트 `C` 입력만 잠근다. 처치 다음 프레임(같은 프레임에 지연 생성된 탄과 확정 드롭을 포함하기 위해)에 그 순간의 적탄을 모두 소거한다. VisibleRect를 사방 **16px** 넓힌 영역 안에 원점이 있는 적탄만 탄 위치에 XP 1 오브로 바꾸고, 영역 밖 적탄은 오브도 XP도 없이 지운다. 레이저·빔은 시작점으로 판단하며 1줄이 1발이다. 소거 뒤 남은 적이 새로 쏜 탄은 일반 탄으로 남는다. 탄이 적은 상태에서 처치해도 보상이 비지 않도록 처치마다 **최소 탄소거 XP**(엘리트 **10** · 보스 **20**)를 둔다. 변환된 오브 수가 최소에 못 미치면 모자란 수만큼 XP 1 오브가 처치 위치 반경 **18px** 안에 흩어져 튀어나온다(예: 엘리트전에서 5발 변환이면 5개 추가). 변환이 최소 이상이면 추가하지 않는다. 화면 밖에서 지운 탄과 처치한 적의 확정 드롭은 최소 계산에 들어가지 않는다. 이어서 최소 보상 오브, 엘리트 확정 드롭, 기존 오브까지 플레이필드의 모든 XP 오브를 함선으로 강제 회수한다. 강제 회수 오브는 매 프레임 남은 거리 ÷ 남은 시간의 속도(최저 **190px/s**)로 날아 거리와 상관없이 **0.6초** 안에 도착하고, 움직이는 함선도 따라잡는다. 회수 시작 뒤 게임플레이 시간 **1.0초**가 지나도 남은 오브는 그 자리에서 즉시 수집한다. 회수한 오브가 모두 XP로 정산된 뒤에만 Threat가 오르고 적 오그먼트 오퍼가 열린다. 예외: 회수 중 함선이 파괴되면 보상을 멈추고 오퍼를 열지 않는다(런 종료). BOSS 관문도 같은 처치 정산(탄소거·XP 회수·Threat 상승·적 오퍼)을 거친다. 항모는 격침 연출(8.2초)이 끝난 뒤에 정산이 시작된다([거대 항모 · 본 게임 연결](bosses/carrier.md#본-게임-연결)).

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
- 탄소거 보상 중 트리가 멈추지 않고 함선이 움직이며, 화면 밖 적탄은 XP 없이 소거되고, 먼 오브도 0.6초 안에 도착하며, 1.0초 상한에서 남은 오브가 즉시 수집되고, 변환이 최소 탄소거 XP(엘리트 10 · 보스 20)에 못 미치면 모자란 수만큼 처치 위치에서 오브가 나오고 최소 이상이면 나오지 않으며, 회수 중 함선이 파괴되면 오퍼가 열리지 않는다. 검증: `tests/bullet_cancel_reward_smoke_test.gd`·`tests/threat_elite_progression_smoke_test.gd`·`tests/boss_carrier_gate_test.gd`.
- 엘리트·오퍼 중 다음 관문 시간이 누적되지 않는다.
- WAVE는 스폰 전에 선행 편대 클리어(잔존 ≤ `handoff_remaining`, 또는 `clear_timeout`)와 `clear_min_wait` 호흡을 거친다. WAVE에는 중앙 경고가 뜨지 않는다.
- 클리어 대기 중 일시정지된 시간은 `clear_min_wait`에서 차감되지 않는다.
- 인계 규칙: 스텝·편대 간격은 바닥 시간 전에는 절대 다음으로 가지 않고, 바닥 뒤 잔존 합계가 `handoff_remaining` 이하이면 즉시, 아니면 천장에서 간다. 멤버 스폰이 끝나지 않은 편대는 잔존을 세지 않고 인계 조건에서 제외한다. `handoff_remaining` 0은 옛 랜덤 대기와 같다.
- `A` 토큰은 풀에서 2편대를 `encounter_gap` 간격으로 내고, 두 편대 모두를 인계 집계에 넣는다.
- ELITE·BOSS 게이트만 `EncounterStepWarning`을 띄우며, 종류별 문구·색과 SFX가 붙고 `step_warning_duration` 뒤 스스로 사라진다.
- 교습 Phase 1~3은 구절 → 풀 추첨 → 구절 순서를 지키고 두 구절이 붙지 않으며, 각 구절은 대안 wave 둘 중 하나를 재생한다. 구절 편대는 그 Phase의 Threat에서 쓸 수 있는 것만 쓴다.

검증 참고: `tests/run_phrase_sequence_test.gd` · `tests/threat_elite_progression_smoke_test.gd` · `tests/encounter_sequence_smoke_test.gd`. Godot 실행은 `tools/run-godot.cmd`를 사용한다.
