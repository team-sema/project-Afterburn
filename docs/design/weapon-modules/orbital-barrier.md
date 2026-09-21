# 무기 모듈 · 궤도 방벽

- 무기 ID: `aux_orbital_barrier`
- 획득 카드: `acquire_aux_orbital_barrier`

## 외형

![궤도 방벽](sprites/weapon_aux_orbital_barrier.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/svg/weapons/weapon_aux_orbital_barrier.svg`
- 인게임 세그먼트 판: `assets/svg/orbital_barrier_segment.svg`

## 기본 동작

- 세그먼트 3개가 함선 주위를 공전하며, Hitbox로 적에게 접촉 피해를 주고 Hurtbox로 적탄·적 히트박스를 흡수한다.
- 세그먼트는 궤도에 맞춘 짧은 판형으로 그린다. `segment_arc_length` **12**, 두께 **4.5**, 스프라이트 `orbital_barrier_segment.svg`.
- 세그먼트마다 **내구 `segment_integrity` = 1**. 받은 피해(히트박스 `damage`)만큼 깎이며, 0 이하가 되면 그 세그먼트는 **파괴**된다.
- 파괴된 세그먼트는 충돌·표시를 끄고, `respawn_delay` **3.0초** 뒤 내구 전부 회복하며 **리스폰**한다. 공전 궤적 자체는 유지한다.
- 내구·리스폰 타이머는 `OrbitalBarrierWeaponSystem`이 세그먼트별로 소유한다.

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 표시명(요지) |
|----------|---------|--------------|
| `barrier_multi` | `trait_barrier_multi` | 다중 방벽 — 방벽 +1→+3 · 피해 ×0.9→0.7 |
| `barrier_fast_orbit` | `trait_barrier_fast_orbit` | 고속 궤도 — 공전 ×1.5→2.1 · 재타격 쿨 ×0.7→0.4 · 피해 ×0.95 |
| `barrier_expand_axis` | `trait_barrier_expand_axis` | 확장 — 반경 ×1.45→1.95 · 크기 ×1.35→1.75 |
| `barrier_repulse` | `trait_barrier_repulse` | 반발 충격 — 밀침 140→260 · 충격 피해 40%→70% · 재타격 쿨 ×0.85 |

기본 방벽은 같은 적에게 한 번만 피해를 준다. 고속 궤도 또는 반발 충격 장착 시 시간 기반 재타격을 허용하며, 기본 1초에 장착 모듈의 쿨다운 배율을 곱한다.

## 완료 조건·검증

- 세그먼트가 내구 한도만큼 피해를 받으면 깨지고, 지연 후 다시 나타난다.
- 깨진 세그먼트는 적·적탄과 충돌하지 않는다.
- `tests/orbital_barrier_break_respawn_smoke_test.gd` 및 기존 방벽 관련 smoke로 확인한다.

상위: [무기 모듈](index.md)
