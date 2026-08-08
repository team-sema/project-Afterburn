# Caster 상단 원형 탄막 · Awl V

## 목표

- Caster: 체력 상향, 상단 체공, 주기적 원형 다연발 탄막
- Awl: 3마리 V로 하강·조준 후, 차지 시작 시 V에서 각자 독립 돌진

## 구현

- `caster_entry_patrol.tres` + `MovementController`, `RadialBarrageShootComponent`
- Awl `awl_charge_formation.tres` + `V3Formation` + `FormationController`; 편대 Sequence 완료 후 `individual_awl_charge.tres`로 전환
- 2026-07-31 `feature/caster-top-orb-barrage` → main (검증 대기)
