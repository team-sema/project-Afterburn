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
| `WAVE` | `EncounterWave` 의 `encounter_preset_paths`를 **순서대로**, 편대 사이 `interval_min~max` 랜덤 | 고정 순서 |
| `ELITE` | 아래 엘리트 게이트를 연다 | `elite_preset` 지정 시 그 preset, 비우면 교대 규칙 |
| `BOSS` | 엘리트 게이트와 같은 흐름 + `is_boss` (엘리트 HP 공식 미적용) | `boss_preset` 비어 있으면 경고 후 **건너뜀** |

`WAVE`/`ELITE`/`BOSS`는 `wait_for_clear`(기본 true)면 WARNING·게이트 전에 Director가 추적 중인 편대가 비울 때까지 기다린다. `clear_timeout` > 0이면 **클리어 또는 타임아웃 중 먼저** 온 쪽으로 진행하고, `clear_min_wait`가 있으면 그 대기 시작부터 최소 그 초만큼은 쉰 뒤 진행한다 (빨리 클리어해도 WAVE 호흡을 남김). `clear_timeout` 0은 클리어만 본다(무한 대기). 대기 시간은 게임플레이 시간(프로세스 델타)으로 계산하므로 오그먼트 선택·탄소거 등 트리 일시정지 동안은 흐르지 않는다.

WAVE·ELITE·BOSS 스텝은 스폰/게이트 직전에 맵 중앙에 `WARNING` 텍스트가 점멸한다 (NORMAL은 없음).

**현재 기본 시퀀스**

| 토큰 | 종류 | 내용 | post_delay · clear |
|---|---|---|---|
| `a` | NORMAL | `MainEncounterPool` 랜덤 | 2.8 ~ 3.1초 |
| `b` | WAVE | `drone_swarm_wave`: 드론 편대 3연속 (straight → triangle → zigzag), 편대 간격 0.55~0.7초 | 5.0 ~ 5.5초 · clear_timeout 6.0 · clear_min_wait 2.5 |
| `c` | ELITE | 교대 규칙 · wait_for_clear (timeout 없음) | 2.8 ~ 3.1초 |
| `d` | BOSS | `boss_wall` (거대 벽 + 출몰 포탑) | 2.8 ~ 3.1초 |

- Phase `main`: `a a a a b a a a b a a a c a a a a b a a a a d`
- 끝나면 같은 Phase를 반복 (`REPEAT_LAST_PHASE`). Phase는 패턴을 담는 단위일 뿐, opening/loop 고정 구조가 아니다.

개발자는 `.tres`의 패턴 문자열·토큰 정의만 고쳐 시나리오를 바꾼다. 현행 규칙·완료 조건은 이 문서를 따른다.

## 일반 Encounter 스폰 (타이머 — Director 미사용 시)

- 주기: **2.8초 + 0~0.3초** 지터 (`EnemyGenerator`, `automatic_spawning_enabled`)
- 선택: `MainEncounterPool` weighted random 1회
- 직전 **2개** Encounter id는 후보에서 제외 (대안이 있을 때)
- weight · min_threat · 등록 목록: [Encounter 카탈로그](encounters/catalog.md)

## Threat · 엘리트 게이트

우선순위(겹칠 때): `boss > elite > augment offer > normal encounter`.

| 단계 | 동작 |
|------|------|
| 게이트 오픈 (`ELITE` 스텝, 또는 Director 미사용 시 60초 타이머) | 사격형 `threat_elite_single` / 돌격형 `threat_elite_awl` 교대로 1기 (`ThreatEliteController`). 스텝의 `elite_preset`이 있으면 그 preset |
| 엘리트 전투 중 | 일반 Encounter 스폰 **정지** (시퀀스도 대기) · 기존 일반 적 유지 |
| 엘리트 처치 | 전투 정지 → 적탄을 XP로 변환 → 화면의 모든 XP 강제 회수 |
| XP 회수 완료 | Threat **+1** → 적 증강 3지선다 |
| 오퍼 완료 | 게이트 닫힘 → 시퀀스 다음 스텝 (타이머 모드면 일반 스폰·다음 Threat 타이머 재개) |
| 전투·오퍼 중 | Threat 시간 **누적 안 함** (연속 엘리트 방지) |

첫 엘리트: Threat **2** 사격형. Threat **3** 돌격형, 이후 짝수 Threat 사격형·홀수 Threat 돌격형으로 교대한다. 여기서 Threat는 처치 후 도달할 관문 목표값이다. 공통 HP 공식은 [엘리트](elites/index.md), 돌격 규칙은 [elite-awl](elites/elite-awl.md).

탄소거 보상 중에는 전투 전체와 플레이어 오그먼트 `C` 입력을 잠근다. 적탄 1발은 XP 1로 변환되며, 기존 XP와 엘리트 확정 드롭까지 실제로 수집된 뒤에만 적 오그먼트 오퍼가 열린다. 아직 미구현인 보스도 향후 같은 공용 보상 컨트롤러를 호출한다.

## Threat HUD

- **시퀀스 모드** (`EncounterDirector` 실행 중): `STAGE MM` + 바 = 현재 스테이지(패턴 1회) 안 스텝 진행도. 패턴이 반복될 때마다 STAGE +1. 엘리트 게이트 중에는 `STAGE MM   ELITE ENGAGED`.
- **타이머 모드** (Director 미사용): 기존 `MM:SS` 카운트다운 (Threat 숫자는 HUD에 표시하지 않음).

## Threat별 로스터 요지

- **Threat 1:** Drone·Striker 호위·Awl 등 (Bomb·Interceptor pair 제외)
- **Threat 2+:** `tanker_guard_sniper` · `bomb_drone_diamond` · `interceptor_pair`
- **Threat 3+:** Caster · V7/X9 하강 · X9 orbit · Interceptor trio

## 페이즈(장) 구성 — 이번 변경

한 판은 여러 페이즈로 나뉘고 페이즈마다 보스가 다르다. 페이즈 = 등장 패턴 1회 + 그 페이즈의 보스. 페이즈 순서와 무작위 여부는 미결정이다.

토큰 패턴(`a a a a b a a a b a a a c a a a a b a a a a` + 보스)과 유닛은 페이즈 간에 공유한다. 페이즈의 정체성은 **배경(항로)**, **패턴 뒤쪽 `a`의 후보 목록**, **보스 진입 연출**로 만들고, 이야기는 화면으로만 전달한다.

### 리사이클러 페이즈 — 해체구역 접근로

마지막에 만나는 것이 [리사이클러](bosses/wall.md)(이동 요새의 자동 해체구역)임을 전투 중 화면만으로 납득시키는 구성이다. 패턴 진행도(스텝 n / 23, 보스 토큰이 23)에 배경 비트를 묶는다.

| 비트 | 패턴 구간 | 배경(항로) | 조우 |
|---|---|---|---|
| 접근 | 1~8 (`a a a a b a a a`) | 열린 우주. 진행 6%부터 화면 위 멀리 요새 실루엣이 점처럼 보이고 점점 커지며 항행등이 깜빡인다. | 공용 풀(Threat 1): 드론·스트라이커·송곳 편대 = 요새 앞 초계. |
| 외벽 | 9~13 (`b a a a c`) | 두 번째 웨이브부터 요새 외벽 판이 위에서 내려와 화면을 채운다(별이 가려짐). `c` 엘리트는 외벽 입구의 문지기. | 엘리트 처치 → 탄소거 → 적 오퍼(기존 게이트 흐름) = 외벽 돌파. |
| 내부 | 14~22 (`a a a a b a a a a`) | 통로 내부: 좌우 벽면과 유도등이 흐르고 폭이 좁아진 인상. | 후보 고정 `a`: `tanker_guard_sniper`(경비 초소) · `interceptor_pair`(순찰) · `bomb_drone_diamond`(기뢰) · `striker_drone_diamond_5`(호위) — 모두 기존 유닛. `b` 드론 웨이브는 격납 편대. |
| 해체구역 | 23 (보스) | 통로가 넓은 구역으로 열리고 스크롤이 멈춘다 → 리사이클러 진입(천장·격벽이 닫힘). | [리사이클러](bosses/wall.md) |

- 내부 구간의 `a` 후보 고정은 시퀀스 데이터로만 만든다: 이 페이즈를 `recycler_approach`(패턴 `a a a a b a a a b a a a c`)와 `recycler_interior`(패턴 `a a a a b a a a a d`, 로컬 `a`의 `encounter_presets` = 위 4개) 두 EncounterSequencePhase로 나눈다. 토큰 글자·유닛·엘리트 게이트 흐름은 그대로다. HUD `STAGE`는 Phase 패스마다 오르므로 페이즈 단위 표시로 바꾸는 작업이 따른다.
- 배경 비트는 `EncounterDirector.sequence_progress_changed`(스텝 진행도)와 ELITE 게이트 신호에 묶는다. 본 게임 항로 아트는 미구현이며, [리사이클러 Lab](bosses/wall.md#lab)의 자리표시 레이어로 흐름을 먼저 확인한다.
- 미결정: 페이즈 순서·무작위, 페이즈 간 전환 연출(보스 격파 후 다음 항로), 페이즈별 Threat 리셋 여부.

## 관련

- [적](enemies/index.md) · [진형](formations/index.md) · [Encounter](encounters/index.md)
- 보스 콘텐츠의 미결정 사항: [미결정·확장 후보](gaps.md)

## 완료 조건·검증

- 엘리트 전투 중 일반 Encounter 생성이 멈추고 기존 일반 적은 유지된다.
- 처치 보상 정산 후 Threat 상승·적 오퍼·다음 구간 순서가 지켜진다.
- 엘리트·오퍼 중 다음 관문 시간이 누적되지 않는다.
- WAVE는 WARNING 전에 선행 편대 클리어(또는 `clear_timeout`)와 `clear_min_wait` 호흡을 거친다.
- 클리어 대기 중 일시정지된 시간은 `clear_min_wait`에서 차감되지 않는다.

검증 참고: `tests/threat_elite_progression_smoke_test.gd` · `tests/encounter_sequence_smoke_test.gd`. Godot 실행은 `tools/run-godot.cmd`를 사용한다.
