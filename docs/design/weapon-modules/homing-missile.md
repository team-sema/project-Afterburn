# 무기 모듈 · 유도탄

- 무기 ID: `aux_homing_missile`
- 획득 카드: `acquire_aux_homing_missile`

## 외형

![유도탄](sprites/weapon_aux_homing_missile.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_aux_homing_missile.svg`
- 타격 이펙트: [공용 규칙](../effects.md#타격-이펙트) · 프로필 `effects/impact_profiles/homing_missile.tres`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 등급 | 표시명(요지) |
|----------|---------|------|--------------|
| `missile_high_mobility` | `trait_missile_high_mobility` | 실버 | 고기동 — 탄속 ×1.15→1.75 · 연사 간격 ×0.96→0.8 |
| `aux_homing_missile_power` | `trait_aux_homing_missile_power` | 실버 | 증량 탄두 — 피해 ×1.08→1.40 |
| `missile_multi_rack` | `trait_missile_multi_rack` | 골드 | 다중 런처 — +1→+3발 · 피해 ×0.9→0.7 |
| `missile_proximity` | `trait_missile_proximity` | 골드 | 근접신관 — 직격 ×0.95 · AOE 80%→100% · 반경 24→40 |
| `missile_terminal` | `trait_missile_terminal` | 골드 | 종말 가속 — 최대 보너스 +100%→+150% · 만개 2.5→2.0초 |

실버 수치는 Lv.I→V, 골드는 Lv.I→III이다.

상위: [무기 모듈](index.md)
