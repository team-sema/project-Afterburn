# 이펙트 · 비주얼

Nova Drift 풍: **밝은 기하 코어 + 다중 글로우 레이어 + 어두운 우주 배경**.

상세 가이드: [`.agents/godot_nova_drift_visual_guide.md`](../../.agents/godot_nova_drift_visual_guide.md)

## World

- `WorldEnvironment` — HDR 글로우/블룸
- `effects/space_background.tscn` — 패럴랙스 스크롤 (약 2 / 5 / 20 px/s)

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
| `laser_beam.gdshader` | 플레이어 레이저 빔 본체 (글로우 + 흐르는 줄무늬, [레이저](weapon-modules/laser.md)) |
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

`effects/augment_resume_burst.tscn` — 플레이어 오그먼트 선택 직후 함선 주변 연출. 실제 탄 제거는 `AugmentOfferController`가 `enemy_projectiles` 그룹을 반경 내 `queue_free`.

## 피드백 컴포넌트

Flash / Scale / Shake — 피격·발사 시 펀치감

- `FlashComponent`: 단일 `sprite` 또는 `flash_root`의 CanvasItem 자식들을 한꺼번에 화이트 플래시 (Tanker 실드 다중 레이어)
- `EntryWarningComponent`: 고속 진입 전 VisibleRect 가장자리 화살표 점멸
- `EncounterStepWarning`: WAVE/ELITE/BOSS 시퀀스 스텝 직전 맵 중앙에 `WARNING` 텍스트 점멸 (빨간색)

## 픽업

- `pickups/experience_orb.tscn` — 사각 **보급 상자** 실루엣 + 황금 글로우(Wide/Tight/Core). 회전하지 않음.

## 아트 소스

- `assets/enemies/` · `assets/player/` · `assets/effects/` — 네온 SVG 마스크
- `assets/weapons/` · `assets/facilities/` — HUD 아이콘 (흰색 마스크, HUD에서 틴트)
- `assets/backgrounds/` — 패럴랙스 배경 PNG
- `assets/ui/` · `assets/pickups/` — UI·픽업 마스크

