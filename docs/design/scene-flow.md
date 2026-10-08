# 씬 플로우

## 기획 의도

중앙 전장을 유지하면서 좌우 HUD로 상태를 읽고, 선택 중에는 전투를 멈춰 판단 시간을 제공한다.

## 확정된 현재 동작

거대 항모 독립 시험은 `labs/bosses/carrier/carrier_boss_lab.tscn`을 F6으로 열거나 Lab 허브에서 선택한다. 중앙 전장 상단에 보스 전체 HP를 고정 표시하고 좌측에는 재시작·일시정지·허브 복귀, 우측에는 피격 횟수와 경과 시간을 표시한다. 규칙은 [거대 항모](bosses/carrier.md)를 따른다. 본 게임 HUD와 엘리트 추적형 HP바는 그대로 유지한다.

개발 시험의 공통 입구는 저장소 루트의 `lab_hub.tscn`이다. 아래 Lab을 목록에서 방향키/Enter로 선택한다. 허브에서 연 Lab은 F1로 목록에 복귀하며, 씬은 하나씩 실행한다. 기존 개별 씬의 F6 실행도 유지한다. 본 게임 시작 씬은 변경하지 않는다. 탄막 스크립트 작업 규칙은 [전투](combat.md)를 따른다.

Lab 배치: 허브만 루트에 두고 각 Lab은 `labs/<주제>/` 아래에 둔다. 새 Lab을 만들면 `lab_hub.gd`의 `LABS` 목록에도 등록한다. 보스 Lab은 보스마다 `labs/bosses/<보스>/` 폴더를 두고 허브에 `보스 · <이름>`으로 등록한다. 허브 복귀용 공용 스크립트는 `labs/lab_return.gd`다.

| 허브 항목 | 진입 씬 |
|---|---|
| 탄막 · 패턴 스크립트 | `labs/bullet/bullet_lab.tscn` (예제별 바로가기 `labs/bullet/presets/`는 허브에 따로 두지 않는다) |
| 보스 · 거대 항모 | `labs/bosses/carrier/carrier_boss_lab.tscn` |
| 보스 · 벽 | `labs/bosses/wall/wall_boss_lab.tscn` |
| 엘리트 · 스나이퍼 공격 패턴 | `labs/enemy_attack/enemy_attack_lab.tscn` (Elite Awl·Fighter·Bomb·Caster·Sniper) |
| 무기 · 증강 · 적 소환 | `labs/weapons/weapon_test_lab.tscn` |
| 증강 카드 · UI | `labs/augment_cards/augment_frame_test.tscn` |

무기 · 증강 · 적 소환 Lab(`weapon_test_lab`)은 640×360 기준에서 좌우 170px 패널과 가운데 300px 전장으로 나눈다. 패널은 Lab 전용 테마(`labs/weapons/weapon_test_lab_theme.tres`, Mulmaru 10px · 얇은 스크롤바 · 작은 SpinBox 화살표)를 쓰고, 버튼은 높이 16px(스폰 목록은 14px)로 이름이 잘리지 않게 한다.

- **좌측 · 적 스폰**: 1회 스폰 수 → Encounter 목록 → 반복 스폰 간격·지속 스폰 → `표적 NN` · `전장 정리`. 목록은 `본 게임 풀`(`main_encounter_pool`) · `엘리트 · 보스` · `특수 스폰`(`sniper_reinforcement`·`elite_escort_drone_pair`) · `기타 · 레거시` 묶음으로 나누고, 행마다 왼쪽 정렬 스폰 버튼과 `반복` 토글을 둔다.
- **우측 · 장비**: 슬롯 버튼(번호 + 장착 무기 아이콘) → 무기 목록(장착 무기는 녹색 · `장착`) → 선택 무기 전용 모듈(활성 시 녹색 · `Lv.N`, 사용법은 툴팁) → `모듈 초기화` · `슬롯 비우기`. 무기 목록과 모듈 목록은 남은 높이를 반씩 나눈다.
- **가운데 배지**: 평소 `C 플레이어 증강 · V 적 증강`, 증강을 고르면 마지막 결과를 보인다.
- **C/V 증강 선택**: 화면을 덮는 패널에 분류 탭과 2열 카드 그리드를 둔다. 카드는 아이콘 · 이름 · 배지 · 설명 2줄이다. 플레이어(C)는 시설 모듈, 적(V)은 `스탯` · `행동` · `편성 · 규칙` · `진화` 탭이다. 배지는 플레이어 `설치 ×N`, 적 `적용됨` · `×N/M` · `랩 전용`이다. 최대 스택 카드는 비활성이다. Q/E로 탭을 옮기고 Esc로 닫는다. Lab의 적 진화 카드는 등장 조건 없이 바로 고를 수 있다.
- **증강 떼기**: 적용된 카드에는 `떼기` 버튼이 붙고, 우클릭도 같은 동작이다(비활성 카드 포함). 누를 때마다 가장 최근 스택 하나를 떼며 선택 창은 열린 채 갱신된다. 헤더 `전부 떼기 (N)`는 현재 모드의 증강을 모두 떼고, 탭에는 `이름 · 카드 수 · 적용 수`를 보인다. 적 증강은 `EnemyAugmentRegistry.remove_augment`로 떼며, 붙일 때처럼 이후 스폰부터 적용된다(진화를 떼면 원본 씬으로 돌아옴). 시설 증강은 `PlayerAugmentRegistry.uninstall_augment`로 슬롯을 비우며 슬롯 수는 유지한다.

## 전이

```text
Menu ─(게임 시작)→ World
  │                 ├─ Ship.tree_exited → 1초 대기 → Game Over ─(메인 메뉴)→ Menu
  │                 └─ Esc → 일시정지 ─(계속하기·Esc)→ World
  │                                   ├─(설정)→ 설정 패널 ─(돌아가기·ui_cancel)→ 일시정지
  │                                   └─(메인 메뉴)→ Menu
  └─(설정)→ 설정 패널 (Menu 위 모달) ─(돌아가기·ui_cancel)→ Menu
```

오그먼트 오버레이는 **씬 전환이 아니라** World 위 오버레이다. 오퍼 중 전투는 일시정지하고, 왼쪽 HUD와 전장을 어둡게 덮은 무대에 카드 3장을 나란히 두며 우측 STATUS는 그대로 보여 미리보기에 쓴다. 상세는 [오그먼트](augments.md#ui-요약).

## 공용 UI 테마 (`menus/ui_theme.tres`)

전투 HUD의 상시 장식은 전장보다 낮은 대비로 둔다. `world.tscn`의 좌우 패널 테두리·전장 경계선·제목 구분선은 기존 RGB의 70%인 `(0.07, 0.455, 0.665)`(알파 0.85), 세 영역 모서리 브래킷은 `(0.14, 0.504, 0.7)`(알파 0.9)로 표시한다. 글자·상태 게이지·장착/포커스 강조색과 170/300/170px 배치는 유지한다. 메뉴의 모서리 장식은 기존 공용 스타일을 따른다.

메뉴 계열 화면(시작화면·설정·일시정지·게임 오버·증강 선택)은 World HUD와 같은 네온 SF 톤을 하나의 `Theme`로 공유한다. 각 화면 루트에 테마를 지정하고, 개별 노드의 `theme_override_*`는 테마로 표현할 수 없는 경우에만 쓴다. World 좌우 HUD는 기존 `LabelSettings`·패널 스타일을 유지한다(같은 팔레트).

- 공용 배경 `menus/menu_backdrop.tscn`: 스크롤 `SpaceBackground` + 메뉴 전용 글로우(`glow_intensity` 1.6, HDR 글자에만 걸림) + 비네트 + 화면 모서리 `NeonCornerFrame`. 시작화면·게임 오버가 사용한다.
- 공용 포커스 `menus/ui_focus.gd`(`UiFocus`): 세로 목록 위/아래 순환 연결, 포커스를 잃었을 때 복구 판정. 모든 메뉴 계열 화면이 사용한다.
- 화면 전환은 0.4초 페이드인 / 0.2초 페이드아웃(시작화면·게임 오버).

| 항목 | 값 |
|---|---|
| 기본 폰트 | Mulmaru 12px. 원본 픽셀 격자가 12px이므로 크기는 12의 배수(12·24·36)만 써서 2배(1280×720)·3배(1920×1080) 화면 모두 선명하게 유지한다 |
| 패널 바탕 | 남색 `(0.018, 0.035, 0.075)`, 불투명도 0.96 · 테두리 1px 청색 `(0.1, 0.65, 0.95)` · 안쪽 여백 14px + 바깥쪽 `NeonCornerFrame` 브래킷 |
| 본문 글자 | 연청백 `(0.82, 0.92, 1.0)` · 보조 글자 `(0.45, 0.62, 0.8)` |
| 강조(포커스) | 시안 `(0.35, 0.88, 1.0)` — 왼쪽 3px 강조선 + 옅은 시안 바탕 |
| 비활성 | 회청색 `(0.3, 0.38, 0.5)` |
| 타입 변형 | `TitleLabel`(36px, HDR 시안 + 글로우) · `GameOverTitle`(36px, HDR 적분홍) · `SubtitleLabel`(12px 자간 2 청색) · `RecordLabel`(12px 자간 2 HDR 금색) · `HeaderLabel`(24px) · `HintLabel`(12px 보조색) · `MainMenuButton`(24px 메인 메뉴 항목) · `SettingsRow`/`SettingsRowFocused`(설정 행 바탕) · `SettingsToggle`(켬 상태는 시안 채움, 자체 포커스 표시 없음) |

포커스와 마우스 호버는 같은 모습이다. 마우스가 항목 위에 올라가면 그 항목이 포커스를 가져간다.

## Menu (`menus/menu.tscn`)

- 타이틀 표시: **갤럭시 메이헴**(36px, 네온 글로우). 그 위에 보조 문구 `PROJECT AFTERBURN`, 아래에 1px 청색 구분선을 둔다. 타이틀 밝기는 ±8%로 천천히 맥동한다.
- 배경: 공용 배경 `menu_backdrop.tscn`. 진입 시 0.4초 페이드인.
- 메뉴 항목(세로): **게임 시작 · 설정 · 종료**. 진입 시 `게임 시작`에 포커스. 위/아래로 이동하고 끝에서 반대쪽으로 순환하며 `ui_accept`로 결정한다. 웹 빌드에서는 `종료`를 숨긴다.
- 포커스를 잃은 상태에서 방향·확인 입력이 오면 기본 항목(`게임 시작`, 설정에서 돌아온 직후엔 `설정`)에 포커스를 복구한다.
- 메뉴 진입 시 World를 비동기로 미리 로드한다. `게임 시작`을 결정하면 메뉴 입력을 잠그고, 로딩이 끝나면 0.2초 페이드아웃 후 전환한다. 전환은 검은 페이드 뒤에서 World를 먼저 트리에 붙이고 메뉴를 지우는 **수동 교체**다. `change_scene_to_packed`는 메뉴를 먼저 지워 World 인스턴스가 끝날 때까지(약 0.3초) 기본 배경색(회색) 빈 프레임이 보이므로 쓰지 않는다. 대기 중에는 메뉴 아래에 `게임 준비 중... N%`를 표시한다. 로딩 실패 시 `게임 로딩 실패`를 표시하고 시작 항목을 비활성화한다.
- 하단: 왼쪽 `최고 점수 000000`(현재 런 기록, 저장되지 않음), 오른쪽 조작 안내 `↑↓ 이동 · Enter 결정`.

## 설정 (`menus/settings_menu.tscn`)

Menu와 일시정지 위에 뜨는 모달 패널이다(씬 전환 아님). 같은 씬을 시작화면(`Menu`의 자식)과 World(루트 자식, 화면 전체)에서 쓴다. 열려 있는 동안 아래 화면의 타이틀·항목은 숨기고 배경만 어둡게 덮어 보이며, 마우스 입력을 막는다.

| 행 | 조작 | 적용 |
|---|---|---|
| 마스터 볼륨 | 좌/우 5% 단위(슬라이더 `step` 0.05), 0–100% | `Master` 버스. 0%면 음소거 |
| 음악 | 〃 | `Music` 버스 |
| 효과음 | 〃 | `SFX` 버스 |
| 전체 화면 | `ui_accept`·좌/우로 켬/끔 전환 | 창 모드 전환 (headless에서는 저장만) |
| 돌아가기 | `ui_accept` | 패널 닫기 |

- 열면 첫 행(마스터 볼륨)에 포커스. 위/아래로 행 이동(끝에서 순환), 포커스된 행은 `SettingsRowFocused` 바탕으로 강조한다. 볼륨 행은 오른쪽에 `N%`를 표시한다.
- `ui_cancel`(Esc) 또는 `돌아가기`로 닫고, 닫으면 연 화면의 `설정` 항목으로 포커스를 돌려준다. 열려 있는 동안 아래 화면 항목은 포커스를 받지 않는다. 일시정지에서 연 경우 Esc는 설정만 닫고 일시정지는 유지한다.
- 변경은 즉시 적용하고 마지막 변경 0.25초 뒤 저장한다.

## 설정 저장 (`GameSettings`, `game_settings.gd`)

- 오토로드 노드 `UserSettings`로 하나만 띄우고 코드에서는 `GameSettings.instance`로 접근한다. 오토로드 전역 이름은 `--script` 테스트에서 컴파일되지 않으므로 쓰지 않는다.
- 파일: `user://settings.cfg`. 키: `audio/master_volume` · `audio/music_volume` · `audio/sfx_volume`(0.0–1.0, 값이 없으면 버스 레이아웃의 현재 볼륨) · `display/fullscreen`(기본 false).
- 게임 시작 시 한 번 읽어 버스 볼륨·창 모드를 적용한다. 메뉴의 설정 패널과 World의 MasterVolumeControl은 모두 `GameSettings`를 통해 읽고 쓰며, 한쪽에서 바꾸면 다른 쪽 표시도 따라간다.
- 저장 실패는 경고만 남기고 게임을 막지 않는다. 테스트·캡처 스크립트는 `GameSettings.instance.save_enabled = false`로 사용자 설정 파일을 건드리지 않는다.

## World (`world.tscn` / `world.gd`)

한 화면을 **왼쪽 HUD · 중앙 전장 · 오른쪽 STATUS** 세 칸으로 나눈다. 각 칸에 `NeonCornerFrame` 모서리 브래킷(장식)이 있다.

### 화면에 보이는 것

| 구역 | 내용 |
|------|------|
| **왼쪽** | 타이틀 → 점수 → XP·STAGE 진행 바 → 실드(미충전 시 충전 게이지) → 그 아래가 전장 뷰포트 안내 |
| **중앙** | 플레이필드 `300×360` — 함선·적·탄·배경이 여기서 움직임. 양옆 패널은 각 170px |
| **오른쪽 STATUS** | 위: 함선 시설(5×3 범용 육각 슬롯, 호버 시 상세) · 아래: 장착 무기·모듈 벌집(클릭/호버로 포커스, 설명은 말줄임·패널 크기 고정) |

세 칸의 폭(170 · 300 · 170px)과 위치는 **고정**이다. 왼쪽 HUD의 동적 라벨(점수·XP·STAGE·실드)은 `clip_text`로 넘치는 글자를 말줄임하며 패널을 넓히지 않는다. XP 충족 표시는 레벨 접두어 없이 `AUGMENT READY [C]`로 써서 칸 폭(134px) 안에 들어간다. 글자가 길어져 패널이 늘어나면 가운데 정렬된 전체 레이아웃이 좌우로 밀리므로, 새 HUD 문구는 134px 안에 맞추거나 라벨을 clip한다.

전장 위에는 평소엔 안 보이지만, 오그먼트 선택 때 **카드 선택 무대**(왼쪽 HUD+전장)와(필요 시) **슬롯/베이 교체 모달**이 오버레이로 뜬다. ESC 일시정지 UI도 같은 World 위다.

### 뒤에서 도는 것 (플레이어가 이름 몰라도 됨)

| 역할 | 담당 |
|------|------|
| 점수·XP·Threat 진행 | 진행 HUD + Threat/엘리트 게이트([런·페이싱](run-pacing.md)) |
| 적 스폰 | Encounter 생성기 — 무엇을 뽑을지는 [카탈로그](encounters/catalog.md) |
| 플레이어/적 오그먼트 보관 | 각각의 레지스트리 (선택 결과를 런 동안 유지) |
| 오퍼 열고 닫기·일시정지 | 오퍼 컨트롤러가 요청 → 선택 UI → 레지스트리 반영 → 재개 |
| 네온 글로우 | 월드 환경(블룸) — [이펙트](effects.md) |

코드/씬 노드 이름(`Ship`, `EnemyGenerator`, `AugmentOfferController` 등)은 구현·디버그용이다. **기획서를 읽을 때는 위 역할 표를 우선**하고, 상세 동작은 플레이어·오그먼트·페이싱 문서로 간다.

### 마스터 볼륨

World 왼쪽 패널에 MasterVolumeControl을 표시한다. 슬라이더는 Master 버스에 즉시 적용되고 0이면 음소거한다. `GameSettings`를 통해 `user://settings.cfg`에 저장하며 일시정지 중에도 조절할 수 있다.

### 런 시작 · 출격 시퀀스 (`effects/launch_sequence.gd`, `LaunchSequence`)

런의 첫 2.6초는 플레이가 아니라 **출격**이다. 함선이 화면 아래에서 애프터버너를 켜고 치고 올라오며, 별이 가속해 선으로 늘어나고, 먹먹하던 음악이 열린다. 목적은 "빠르다"는 감각을 첫 화면에서 몸으로 주는 것이다. 동작은 게임플레이 시간으로 계산하며 입력 잠금 동안 Esc 일시정지는 그대로 된다.

| 구간 | 시각 | 함선 | 배경 (`SpaceBackground.speed_scale`) | 소리 |
|---|---|---|---|---|
| 점화 | 0 ~ 0.5초 | 화면 아래 40px에 정지(`y = 전장 높이 + 40`), 이동 입력·클램프·무기 발사 잠금(무기 로드아웃 `PROCESS_MODE_DISABLED`), 엔진 화염이 커지기 시작 | 0 → 0.3 (별이 겨우 움직임) | 음악 먹먹함 유지(로우패스 500Hz) |
| 연소 | 0.5 ~ 1.6초 | 0.3초부터 홈 위치(씬의 `Ship` 위치, `(100, 216)`)까지 ease-out cubic로 상승, 앵커 ±2px 진동, 엔진 화염 세로 3배·`speed_scale` 2.5 | 0.3 → 7.0 (가까운 별층 1120px/s), 스트릭 선 표시 | 0.3초에 `sounds/launch_burn.wav`(합성 엔진 굉음, SFX 버스) 1회. 0.6 ~ 1.4초에 로우패스가 500 → 20500Hz로 열림 |
| 정착 | 1.6 ~ 2.6초 | 1.8초에 입력·클램프·무기 발사 해제(이후 함선은 플레이어 것), 화염·진동 원복 | 7.0 → 1.0 (순항) ease-in | — |
| 종료 | 2.6초 | 함선은 플레이어가 옮긴 위치를 유지(홈으로 되돌리지 않음). `launch_finished` → `EncounterDirector.start_sequence()` (씬의 Director는 `autostart = false`) | 순항 | — |

- 시작 조건은 Director와 같다. `LaunchSequence`가 `_ready`에서 `current_scene`이 있을 때만 스스로 재생하므로 테스트에서 씬을 붙여도 돌지 않고, `play()`로 직접 재생한다. 재생 중이 아니면 함선·입력·Director는 지금까지와 같다.
- 음악 먹먹함: `Music` 버스의 `AudioEffectLowPassFilter`(버스 레이아웃에 상주, 기본 열림). 시작화면이 열릴 때 닫고(`LaunchSequence.set_music_muffled(true)`), 출격의 연소 구간에서 연다. 일시정지·게임 오버에서 메뉴로 돌아가면 다시 닫힌다.
- 건너뛰기는 없다(2.6초). 체감이 길어지면 이 표의 시각만 줄인다. 출격 중 왼쪽 HUD의 Threat 표시는 Director가 아직 시작 전이라 타이머 모드(`MM:SS`)로 보이다가 시작과 함께 `STAGE`로 바뀐다.

완료 조건·검증: 재생 전 함선·입력·Director가 기존 상태, 재생 시작에 함선이 화면 밖·입력 잠금·음악 먹먹함, 연소 중 `speed_scale` 3 이상과 스트릭, 1.5초에 로우패스가 열리는 중, 1.8초 이후 입력 해제(해제 시점에 홈 위치), 종료 시 해제 뒤 플레이어가 옮긴 위치 유지·순항 속도·Director 실행·`launch_finished` — `tests/launch_sequence_test.gd`.

### 라이프사이클

1. `_ready`: `game_stats.score = 0`, 점수 라벨 연결
2. `Ship.tree_exited`: 1초 대기 후 Game Over 씬으로 이동
3. 오그먼트 오퍼 중: `get_tree().paused = true` (오버레이 `PROCESS_MODE_ALWAYS`)
4. **ESC** (`world_shell.gd`): 수동 일시정지 토글 · 일시정지 메뉴(`PauseOverlay`) 표시. 오그먼트 등 **다른 시스템이 건 pause** 중에는 ESC로 해제하지 않음

### 일시정지 (`menus/pause_menu.tscn`, World `Layout/Playfield/PauseOverlay`)

- 중앙 전장(300×360)만 어둡게 덮고 좌우 HUD는 그대로 보인다. `PAUSED` 보조 문구 + `일시 정지`(24px) + 구분선 아래에 **계속하기 · 설정 · 메인 메뉴**(`MainMenuButton`), 하단에 `Esc 계속하기` 안내.
- 열면 `계속하기`에 포커스. 위/아래 순환, `ui_accept` 결정. `Layout`이 일시정지 시 멈추므로 메뉴 자체는 `PROCESS_MODE_ALWAYS`로 입력을 받는다.
- `계속하기`·Esc → 재개. `설정` → 설정 패널(일시정지 유지). `메인 메뉴` → 일시정지 해제 후 Menu로 전환하며 진행 중 점수는 최고 점수에 반영하지 않는다.

## Game Over (`menus/game_over.tscn`)

- 공용 배경 위에 `MISSION FAILED` 보조 문구 + **게임 오버**(`GameOverTitle`) + 점수 패널.
- 점수 패널: `점수`(24px 6자리) · `최고 점수`(12px 보조색 6자리). `score > highscore`이면 highscore를 갱신하고 `NEW RECORD`(금색)를 표시한다.
- 항목은 **메인 메뉴** 하나이며 진입 시 포커스. `ui_accept` → 0.2초 페이드아웃 후 Menu.

## 오그먼트 오버레이 플로우

1. 적 사망 시 경험치 오브 드롭 → 플레이어 접촉 시 경험치 획득
2. XP가 요구량을 채워도 **자동으로 열리지 않음**. `open_augment_offer`(**C**)로 PLAYER 오퍼 요청 · 오퍼 UI가 이미 열려 있으면 XP 미소모
3. 시퀀스 ELITE 스텝 → 다음 Threat 엘리트 1기 소환. 현재 Threat는 유지하고 일반 Encounter와 시퀀스는 대기한다. Director 미사용 시에만 60초 타이머로 요청한다.
4. 엘리트 처치 → pause 없이 화면 안 `enemy_projectiles`를 탄 위치의 XP 1 오브로 변환(화면 밖은 XP 없이 소거). 기존 XP와 엘리트 확정 드롭도 함께 플레이어에게 강제 흡수하며 이 동안 `C` 플레이어 오퍼 입력을 잠금
5. 모든 XP의 실제 정산 완료 → Threat 상승 → ENEMY 오퍼 요청. pause는 오퍼가 연다
6. `AugmentOfferController.request_offer(type)` → `offer_started(type)` → pause. 강화 분기점 인트로는 PLAYER 청색 / ENEMY 적색 테마로 구분
7. PLAYER 오퍼는 상단 3지선다와 하단 `범용 슬롯 +1`을 함께 표시. `FACILITY_EFFECT`는 우측 STATUS 범용 육각 슬롯의 같은 tag·빈 칸 미리보기, 무기 Kind는 병기 배치·모듈 레벨 미리보기를 표시하되 하단 슬롯 확장 버튼은 바꾸지 않음
8. 시설 카드 → 범용 빈 슬롯 설치(가득 차면 전체 슬롯 교체 모달). 무기 Kind(획득·모듈 강화) → 로드아웃에 직접 적용(만석 획득은 베이 교체 UI). `범용 슬롯 +1`은 Kind와 무관하게 선택 가능(포커스/호버 → 다음 육각 칸 점멸, 선택 → 용량 +1; 시작 5, 최대 15면 비활성)
9. ENEMY 오퍼는 기존 3지선다 선택 → registry 반영
10. **PLAYER 오퍼 종료 직후** 함선 주변 `enemy_projectiles` 제거 + `augment_resume_burst` VFX (`player_resume_clear_radius` 기본 36)
11. unpause → `offer_completed(type)`. ENEMY 오퍼였다면 게이트를 닫고 시퀀스 진행 재개 (Director 미사용 시에만 일반 스폰·새 60초 타이머 재개)
12. 대기 중인 오퍼가 있으면 deferred로 재요청

---

## 완료 조건·검증

- 메뉴→플레이→게임 오버→메뉴 흐름이 완료된다.
- 다른 시스템이 소유한 일시정지를 ESC로 해제할 수 없다.
- 방향 입력과 확인만으로 선택·교체를 완료하고 모달 복귀 시 유효 포커스를 복원한다.
- 시작화면·일시정지에서 방향키·Enter·Esc만으로 모든 항목과 설정 열기/닫기에 도달한다. 설정에서 돌아오면 `설정` 항목에 포커스가 있다.
- 일시정지에서 설정을 열고 닫아도 게임은 멈춘 상태를 유지한다.
- 게임 오버에서 최고 점수를 넘으면 `NEW RECORD`가 보이고, Enter로 메인 메뉴로 돌아간다.
- 설정 패널의 볼륨 변경이 해당 버스에 즉시 반영되고, 재실행 후에도 유지된다. World 볼륨 슬라이더와 값이 일치한다.
- 시작화면·설정·일시정지·게임 오버가 공용 테마를 사용하고 640×360에서 글자가 잘리거나 겹치지 않는다.
- XP 충족·탄소거 보상·엘리트 게이트로 HUD 글자가 바뀌어도 World 세 칸의 위치·폭이 변하지 않는다.
- 시작화면에서 World로 넘어갈 때 검은 페이드 외의 색(기본 배경색 회색)이 한 프레임도 보이지 않는다.

검증 참고: `tests/hud_layout_stability_test.gd` · `tests/pause_smoke_test.gd` · `tests/menu_loading_smoke_test.gd` · `tests/settings_menu_smoke_test.gd` · `tests/game_over_smoke_test.gd` · `tests/master_volume_control_test.gd`. Godot 실행은 `tools/run-godot.cmd`를 사용한다.
