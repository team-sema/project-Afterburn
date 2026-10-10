# 이펙트 · 비주얼

Nova Drift 풍: **밝은 기하 코어 + 다중 글로우 레이어 + 어두운 우주 배경**.

상세 가이드: [`.agents/godot_nova_drift_visual_guide.md`](../../.agents/godot_nova_drift_visual_guide.md)

## World

- **전투 판독성**: 배경 별은 탄·기체보다 낮은 밝기로 둔다. `FarStars`는 RGB 0.65, 큰 십자별이 있는 `CloseStars`는 RGB 0.4의 중립색 `self_modulate`를 적용한다(알파 1). 별의 배치·밀도·스크롤과 출격 스트릭은 유지하며 공용 배경을 쓰는 메뉴에도 같은 명도를 적용한다.
- `WorldEnvironment` — HDR 글로우/블룸
- **파손 궤도 링**: 기본 배경의 주인공은 화면 밖까지 이어지는 거대한 환형 인공 구조물이다. 청록색 금속 외벽·반복되는 장갑판/트러스·끊어진 두 단면의 주황 잔열과 부유 파편으로 크기와 파손 상태를 읽힌다. 구조물 안쪽에는 어두운 행성의 가장자리를 두고, 플레이어가 주로 머무는 화면 하단 중앙은 낮은 대비로 유지한다. 광원은 국소적인 단면에 집중하며 전장 전체 섬광이나 탄환처럼 이동하는 밝은 점은 쓰지 않는다.
  - `BackdropTheme.orbital_ring_enabled`로 켜고 끈다. 기본 테마는 링을 켜고 기존 작은 고리 행성·소행성을 비운다. 다른 테마의 기존 성운·소행성·행성 구성은 계속 지원한다.
  - 링·행성·잔열·파편을 합성한 셰이더 출력 RGB에 0.92를 곱해 색을 살짝 누른다. 색상 비율과 불투명도는 유지해 단면의 주황색과 구조물의 별 가림은 보존한다.
  - `effects/orbital_ring.gdshader`를 쓰는 화면 크기 레이어를 두 별층 위·출격 스트릭 아래에 배치해 구조물 몸체가 별을 가린다. 링은 타원 궤도면을 따라 초당 0.015rad(약 0.86°)로 회전한다. 장갑판·파손 구간·파편이 함께 회전하며 행성은 회전시키지 않는다. 링과 행성의 중심은 180초 주기·짧은 화면변의 6% 진폭으로 처음에는 천천히 내려갔다가 부드럽게 올라온다(300px 전장 기준 최대 ±18px, 시작 하강 속도 약 0.63px/s). 세로 타일링·순간 위치 리셋 없이 원경을 유지하며 잔열 맥동도 계속한다. 시간은 `SpaceBackground`의 게임 시간에서 전달하고 `speed_scale`을 따라 진행하므로 출격 가속과 연결되며, 일시정지·속도 0에서는 멈춘다. 뷰포트 크기에 맞춰 다시 구성하고 테마 해제 시 제거한다.
  - 메뉴는 같은 배경을 사용하며 가로 화면에서도 링의 비율을 유지하되, 메뉴 항목을 가리지 않도록 중심을 위로 옮긴다. 완료 조건은 300×360 전장/640×360 메뉴에서 구조물 형태와 파손 단면이 읽히고, 탄과 피격점을 가리지 않으며, 일시정지·리사이즈·테마 전환이 동작하는 것이다.
- `effects/space_background.tscn` (`SpaceBackground`) — 패럴랙스 스크롤. 순항 속도 12 / 40 / 160 px/s(우주·먼 별·가까운 별)에 `speed_scale`을 곱한다. `speed_scale`이 2를 넘으면 시안-흰색 스트릭 선 24개가 가까운 별층 속도로 흐르며 길이·밝기가 속도에 비례한다(최대 80px). 출격 시퀀스가 0 → 7 → 1로 몰아간다 ([씬 흐름 · 출격 시퀀스](scene-flow.md#런-시작--출격-시퀀스-effectslaunch_sequencegd-launchsequence)). 시작화면 배경도 같은 씬이라 순항 속도로 흐른다
- **배경 디테일 (`BackdropTheme`, `effects/backdrop_theme.gd`)**: 순수 검정 별밭은 글로우 적이 뭉개져 보이므로, 우주층과 먼 별층 사이에 데이터로 만든 두 층을 더 둔다. `SpaceBackground.backdrop`에 꽂은 리소스(기본 `resources/backdrop/default_backdrop.tres`)를 읽어 뷰포트 크기에 맞춰 만들고, 뷰포트가 바뀌면 다시 만든다. null이면 별밭만 그린다.
  - **성운층** `NebulaLayer`: 뷰포트 전체를 덮는 바탕색(`base_tint`, 기본 짙은 남보라 알파 0.55)으로 검정을 들어 올리고, 그 위에 방사형 그라데이션 색 면(`nebula_positions`(뷰포트 비율)·`nebula_radii`(px)·`nebula_colors`) 4장. 색은 적 분홍과 보색 범위(보라·남색·청록)로 제한한다. 6 px/s로 가장 느리게 흐른다.
  - **실루엣층** `RockLayer`: 테마에 지정된 검은 소행성 다각형(`rock_positions`·`rock_sizes`, 7각 불규칙, 인덱스 시드라 모양이 고정)과 작은 고리 행성(`planet_radius` 0이면 없음). 26 px/s. 기본 테마는 파손 궤도 링에 집중하도록 이 층을 비운다.
  - 두 층 모두 별층처럼 뷰포트 높이로 세로 타일링하며 `speed_scale`을 따른다. 별층 속도·스트릭·`get_layer_speed`는 그대로다.
  - 스테이지 테마가 생기면 Phase별 `BackdropTheme`로 바꿔 끼우는 것이 의도이며, 지금은 기본 테마 하나다.
  - 검증: `tests/space_backdrop_smoke_test.gd` (링/기존 테마 생성·층 순서·타일링·스크롤·일시정지·리사이즈·테마 해제).

## 스프라이트 레이어 (함선·적·탄)

`DiffuseGlow` · `WideGlow` · `TightGlow` · `Core` (+ 엔진/궤적 GPUParticles)

## 머티리얼 · 셰이더

| 에셋 | 용도 |
|------|------|
| `additive_unshaded_material.tres` | 가산 합성 |
| `core_unshaded_material.tres` | 코어 |
| `diffuse_glow` / `tight_glow` / `wide_glow` | 글로우 단계 |
| `white_flash_material` | 피격 플래시 |
| `glow_blur.gdshader` | 블러 글로우 |
| `laser_beam.gdshader` | 플레이어 레이저 빔 본체 (글로우 + 흐르는 줄무늬, [레이저](weapon-modules/laser.md)). 항모 선미 배기·함교 레이저도 색만 바꿔 재사용 ([거대 항모](bosses/carrier.md)) |
| `singularity_lens.gdshader` · `singularity_lens.gd` | 플라즈마 특이점의 화면 왜곡 렌즈. 화면 텍스처를 다시 읽어 배경까지 비틀고 붕괴 충격파를 그린다 ([플라즈마 특이점](weapon-modules/plasma-bomb.md#특이점-프리즘)) |
| `impact_vfx.gd` · `impact_profiles/` | 플레이어 무기 공용 타격 이펙트 ([타격 이펙트](#타격-이펙트)) |

## 폭발

`effects/explosion_effect.tscn` + `neon_explosion.gd` — 색상 지정 가능, `"explode"` 후 free

## 타격 이펙트

플레이어 무기의 명중은 모두 같은 형태 언어(섬광 + 스파크, 범위 피해는 링 추가)로 표시하고 색으로 무기를 구분한다. 적의 흰색 피격 플래시와 별개다.

- 렌더러: `effects/impact_vfx.gd`(`ImpactVfx`). `gameplay_world` 그룹 노드(없으면 현재 씬 → 루트) 아래에 처음 명중 때 하나 만들고 모든 무기가 공유한다. 가산 합성, `z_index` **10**(적 위, 적 체력바 아래)이다. 탄이 명중과 함께 사라져도 이펙트는 남는다.
- 무기별 수치: `effects/impact_profiles/<무기>.tres`(`ImpactProfile`). 각 무기 스크립트의 `impact_profile` export 기본값이다.
- 섬광: 방사형으로 흐려지는 원(외곽 = 반지름 × 2.2, 코어 = × 0.8)이 수명 동안 60%까지 줄며 사라진다.
- 스파크: `spark_count` × 강도(반올림, 최소 1)개가 분사 방향 ± `spark_spread_degrees` 원뿔로 튄다. 속도 감쇠 `exp(-drag·t)`, 수명은 개체별 70~100%이며, 진행 방향으로 길이 `spark_length` 선을 그린다.
- 분사 방향은 탄 진행의 반대(맞고 튕겨 나옴)다. 레이저는 아래, 방벽은 적에서 세그먼트 쪽, 플라즈마 폭탄은 전방위(±180°)다.
- 강도: 관통·도탄으로 탄이 계속 날아가는 중간 명중은 **0.6**, 탄이 사라지는 명중은 **1.0**이다. 섬광 반지름과 스파크 수에 곱한다.
- 범위 링: 보조 캐넌 고폭 탄두(`aux_he_shell`)와 유도탄 근접신관(`missile_proximity`)처럼 범위 피해가 있으면 실제 피해 반경의 40%→100%로 **0.25초** 동안 퍼지는 링(두께 1.5px)을 더한다.
- 오버차지: 발사원(탄 또는 무기)의 `OverchargeVisualComponent`가 활성이면 섬광·스파크·링 색에 오버차지 틴트를 곱한다. 탄은 발사 시점 상태를 따른다.
- 동시 표시 상한은 스파크 **256** · 섬광 **64** · 링 **16**이며 넘치면 새 표시를 생략한다. 트리 일시정지 동안 멈춘다.

| 프로필 | 색 (탄 색 기준) | 섬광 반지름 | 스파크 | 속도 px/s | 퍼짐 | 수명 | 비고 |
|--------|----------------|------------|--------|-----------|------|------|------|
| `shotgun` | 황색 | 2.5 | 2 | 100~200 | ±60° | 0.2 | 펠릿 명중 |
| `blaster` | 청록 | 4.0 | 3 | 120~220 | ±60° | 0.25 | 분열·도탄 포함 |
| `orbital_barrier` | 청백 | 4.0 | 3 | 100~200 | ±60° | 0.25 | 세그먼트·적 중간 지점 |
| `laser` | 청록·백 | 4.5 | 4 | 140~260 | ±70° | 0.3 | 데미지 틱마다 |
| `aux_cannon` | 녹색 | 6.0 | 5 | 140~260 | ±70° | 0.3 | 고폭 탄두 링 |
| `homing_missile` | 분홍 | 6.0 | 6 | 150~280 | ±80° | 0.3 | 근접신관 링 |
| `plasma_bomb` | 보라·청 | 없음 | 8 | 160~300 | ±180° | 0.35 | 기존 폭발 위에 추가, 분열 자탄은 강도 0.5 |

완료 조건: 모든 플레이어 무기가 명중 시 자기 프로필로 섬광·스파크를 내고, 범위 피해에는 링이 붙으며, 오버차지 중 발사한 탄은 틴트된 이펙트를 낸다. 수명 뒤 사라지고 상한을 넘지 않는다. `tests/impact_vfx_smoke_test.gd`로 확인한다.

## 오퍼 재개 버스트

`effects/augment_resume_burst.tscn` — 플레이어 오그먼트 선택 직후 함선 주변 연출. 실제 탄 제거는 `AugmentOfferController`가 `EnemyBullets.query_circle`로 반경 내 적탄을 찾아 이유 `augment_resume`으로 `cancel_all`한다.

- 반경은 `player_resume_clear_radius` **36px**이고, 연출의 글로우·링도 같은 반경과 플레이어 강조색으로 퍼진다.
- 제거 대상은 게임플레이 월드 안에서 탄 중심이 반경 안에 있는 적탄이다. 플레이어 탄은 남긴다.
- 검증: `tests/augment_resume_burst_smoke_test.gd` (반경 안 적탄 2발만 제거, 반경 밖 적탄·플레이어 탄 유지, 연출 생성).

## 피드백 컴포넌트

Flash / Scale / Shake — 피격·발사 시 펀치감

- `FlashComponent`: 단일 `sprite` 또는 `flash_root`의 CanvasItem 자식들을 한꺼번에 화이트 플래시 (Tanker 실드 다중 레이어)
- `EntryWarningComponent`: 고속 진입 전 VisibleRect 가장자리 화살표 점멸
- `EncounterStepWarning`: ELITE/BOSS 관문 직전 맵 중앙 관문 경고 — 종류별 문구·색(ELITE 주황빨강 · BOSS 자홍), 펼쳐지는 검은 띠 + 해저드 스트라이프 + 테두리 맥동 + 클락슨 SFX. WAVE는 경고 없음 ([런 페이싱](run-pacing.md#관문-경고-encounterstepwarning))

## 픽업

- `pickups/experience_orb.tscn` — 사각 **보급 상자** 실루엣 + 황금 글로우(Wide/Tight/Core). 회전하지 않음.

## 아트 소스

- `assets/enemies/` · `assets/player/` · `assets/effects/` — 네온 SVG 마스크
- `assets/weapons/` · `assets/facilities/` — HUD 아이콘 (흰색 마스크, HUD에서 틴트)
- `assets/backgrounds/` — 패럴랙스 배경 PNG
- `assets/ui/` · `assets/pickups/` — UI·픽업 마스크


## 공용 위험 표시

`effects/danger_indicator.gd` (`DangerIndicator`)는 전투 로직에 의존하지 않는 Node2D 표시다. 기존 방위각 눈금·브래킷이 수렴하고 같은 중심의 화살표가 진입 방향으로 0.18초 동안 뻗은 뒤 맥동한다. 문구나 숫자는 없다.

- 설정: `warning_color`(기본 청록 #35ffe1), `warning_scale`(기본 1), `warning_duration`(기본 0.9초), `inward_direction`(눈금이 열리는 방향), `trajectory_direction`(화살표 방향). 위치는 Node2D 위치로 지정한다. 방향은 표시 노드 로컬 좌표 기준이며 0벡터 궤도는 inward 방향으로 대체한다.
- 기본 눈금 반지름은 28→20px, 화살표는 5→24px. 색의 알파와 크기 설정은 모든 선에 함께 적용한다. 시간 만료 시 숨기고 해제하며 일시정지 때 멈춘다.
- `auto_advance=false`는 Lab처럼 외부 시간이 소유하는 경우 사용한다. `set_preview_time()`으로 동일 렌더러를 재생·되감기한다.
- `EntryWarningComponent`는 이 표시를 상속하여 화면 가장자리 배치만 담당한다. 인터셉터 최초/왕복 진입은 실제 이동 벡터를 전달하며 각각 기존 0.9/0.6초를 유지한다. 엘리트 재진입은 기존 붉은색과 경고 시간을 유지한다.
- 검증: 공용 표시의 시간 만료·되감기·방향·설정, 인터셉터와 진화형 및 엘리트 경고 회귀, Lab 렌더를 확인한다.
