# Task: overcharge-visual-xp-drift

## Canonical docs

- [reactor.md](../ship-modules/reactor.md)
- [components.md](../components.md)

## Scope

- `components/overcharge_visual_component.gd`
- `components/ship_combat_buff_controller.gd`
- `player_ship/weapons/*`, `projectiles/*` (과충전 틴트·피해 스냅샷)
- `pickups/experience_orb.gd`
- `docs/design/ship-modules/reactor.md`, `docs/design/components.md`
- `tests/overcharge_weapon_visual_smoke_test.gd`, `tests/augment_progression_smoke_test.gd`, `tests/weapon_system_tuning_test.gd`

## Work

1. 과충전 활성 시 무기/탄 붉은 틴트와 발사 시점 피해 스냅샷을 연결한다.
2. XP 오브 기본 낙하 속도를 플레이어 기본 이동 속도(140px/s)와 맞춘다.

## Verification

- [x] overcharge visual smoke PASS
- [x] augment progression smoke PASS
- [x] weapon system tuning PASS
