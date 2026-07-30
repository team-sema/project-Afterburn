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

## 폭발

`effects/explosion_effect.tscn` + `neon_explosion.gd` — 색상 지정 가능, `"explode"` 후 free

## 오퍼 재개 버스트

`effects/augment_resume_burst.tscn` — 플레이어 오그먼트 선택 직후 함선 주변 연출. 실제 탄 제거는 `AugmentOfferController`가 `enemy_projectiles` 그룹을 반경 내 `queue_free`.

## 피드백 컴포넌트

Flash / Scale / Shake — 피격·발사 시 펀치감

## 픽업

- `pickups/experience_orb.tscn` — 사각 **보급 상자** 실루엣 + 황금 글로우(Wide/Tight/Core). 회전하지 않음.

## 아트 소스

- `assets/svg/` — 현재 네온 벡터
- `assets/svg/weapons/` — 무기 HUD 아이콘 (흰색 마스크, HUD에서 틴트)
- `assets/*.png` — 튜토 레거시 스프라이트 (공존)
