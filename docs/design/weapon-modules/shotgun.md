# 무기 모듈 · 샷건

- 무기 ID: `main_shotgun`
- 획득 카드: `acquire_main_shotgun`

## 외형

![샷건](sprites/weapon_main_shotgun.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_main_shotgun.svg`
- 타격 이펙트: [공용 규칙](../effects.md#타격-이펙트) · 프로필 `effects/impact_profiles/shotgun.tres`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 등급 | 표시명(요지) |
|----------|---------|------|--------------|
| `shotgun_choke` | `trait_shotgun_choke` | 실버 | 초크 — 산탄각 ×0.9→0.5 · 탄 수명 ×1.1→1.5 |
| `main_shotgun_power` | `trait_main_shotgun_power` | 실버 | 강화 장약 — 피해 ×1.08→1.40 |
| `shotgun_expanded_shell` | `trait_shotgun_expanded_shell` | 골드 | 확장 산탄 — 펠릿 +4→+8 · 피해 ×0.85→0.75 |
| `shotgun_cut_barrel` | `trait_shotgun_cut_barrel` | 골드 | 단축 총열 — 근거리 피해 ×1.8→2.4 · 판정 거리 80→100 · 산탄각 ×1.5 · 탄 수명 ×0.85 |
| `shotgun_burst_device` | `trait_shotgun_burst_device` | 골드 | 버스트 장치 — 3발마다→2발마다 추가 사격 · 피해 ×0.9→1.0 |

실버 수치는 Lv.I→V, 골드는 Lv.I→III이다.

초크는 탄 수명만 늘리므로 사거리도 수명 배율만큼 늘어난다(Lv.V ×1.5). 초크·단축 총열 카드는 탄 수명 배율을 그대로 표기한다.

버스트 추가 사격은 실제 사격 직후 `delay`만큼 기다렸다 나가며, 그 대기는 트리 일시정지 동안 멈춘다.

상위: [무기 모듈](index.md)
