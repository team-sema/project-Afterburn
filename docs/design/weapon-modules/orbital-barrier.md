# 무기 모듈 · 궤도 방벽

- 무기 ID: `aux_orbital_barrier`
- 획득 카드: `acquire_aux_orbital_barrier`

## 외형

![궤도 방벽](sprites/weapon_aux_orbital_barrier.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/svg/weapons/weapon_aux_orbital_barrier.svg`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 표시명(요지) |
|----------|---------|--------------|
| `barrier_multi` | `trait_barrier_multi` | 다중 방벽 — 방벽 +1→+3 · 피해 ×0.9→0.7 |
| `barrier_fast_orbit` | `trait_barrier_fast_orbit` | 고속 궤도 — 공전 ×1.5→2.1 · 재타격 쿨 ×0.7→0.4 · 피해 ×0.95 |
| `barrier_expand_axis` | `trait_barrier_expand_axis` | 확장 축 — 반경 ×1.45→1.95 · 크기 ×1.35→1.75 |
| `barrier_repulse` | `trait_barrier_repulse` | 반발 충격 — 밀침 140→260 · 충격 피해 40%→70% · 재타격 쿨 ×0.85 |

기본 방벽은 같은 적에게 한 번만 피해를 준다. 고속 궤도 또는 반발 충격 장착 시 시간 기반 재타격을 허용하며, 기본 1초에 장착 모듈의 쿨다운 배율을 곱한다.

상위: [무기 모듈](index.md)
