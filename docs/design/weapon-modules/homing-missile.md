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
| `missile_mark_prism` | `trait_missile_mark_prism` | 프리즘 | 표적 지정 — 명중한 적 4초 표식 · 표식 적이 모든 무기에게 받는 피해 ×1.3 · 미사일 피해 ×0.5 |

실버 수치는 Lv.I→V, 골드는 Lv.I→III이다.

### 표적 지정 (프리즘)

- 미사일이 직격한 적에 `mark_duration` **4초** 표식(`TargetMarkComponent`)을 붙인다. 이미 표식이 있으면 남은 시간을 4초로 되돌린다. 근접신관 범위 피해를 받은 적에게는 붙이지 않는다.
- 표식이 있는 적은 모든 플레이어 무기에게 받는 피해가 ×`mark_damage_mult` **1.3**이다. 투사체·빔·폭발·잔류 장·방벽 접촉 피해가 모두 맞는 순간 따른다(`WeaponSystem.get_target_damage_multiplier`, 보스 배율과 곱함). 미사일 자신의 피해도 포함된다.
- 미사일은 표식 없는 적을 먼저 노린다. 추적 중인 적에 표식이 생기면 다음 재조준 때 표식 없는 적으로 바꾸고, 모두 표식이면 가장 가까운 적을 노린다.
- 미사일 피해 ×`damage_mult` **0.5**.
- 표식은 적 위에서 도는 자홍색 꺾쇠 4개로 보이고, 마지막 1초는 깜박인다. 시간은 게임플레이 시계를 따라 트리 일시정지 동안 멈춘다.
- 대가: 미사일 자체 피해가 절반이 되어 다른 무기가 함께 있어야 힘을 낸다.

## 완료 조건·검증

- 표적 지정을 장착하면 미사일이 맞힌 적에 표식이 붙고, 그 적은 다른 무기에게도 ×1.3 피해를 받는다. 표식은 4초 뒤 사라지고, 미사일은 표식 없는 적을 먼저 노린다 (`tests/prism_weapon_modules_test.gd`).

상위: [무기 모듈](index.md)
