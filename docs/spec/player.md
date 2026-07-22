# 플레이어

## Ship (`player_ship/ship.gd`)

- 그룹: `"player"`
- `PlayerAugmentRegistry` 주입 → `PlayerAugmentApplier.initialize`
- `WeaponMount` 아래 모든 `WeaponSystem` 수집
- 무기 `fired` → `ScaleComponent.tween_scale()`

### 주요 자식

Move / MoveInput / PositionClamp / WeaponMount(Blaster+Laser) / PlayerAugmentApplier / Scale / Stats(**HP 1**) / PlayerHitPoint / Hurt / ExplosionSpawner / Destroyed

## PlayerHitPoint

- 코어 히트 반경(기본 **3px**)
- Hurtbox CollisionShape + 비주얼 스케일
- 플레이어 Hurtbox 위치 (기본 **layer 1** `player_hurtbox`)

## 무기

| 클래스 | 동작 |
|--------|------|
| `WeaponSystem` | 전역/로컬 연사·데미지 배수 API · `fired` |
| `BlasterWeaponSystem` | L/R 교대 · 타이머 **0.15s** · `player_blaster.tscn` |
| `LaserWeaponSystem` | RayCast(mask 2) 연속빔 · tick마다 hurtbox에 `hurt` |

두 무기는 **항상 장착**. 교체/해금 플로우 없음.

## PlayerAugmentApplier

`augment_added` / `augments_cleared` / `refresh()` 시:

- `MOVE_SPEED` → `MoveComponent.velocity_multiplier`
- `FIRE_RATE` / `WEAPON_DAMAGE` → 각 WeaponSystem 전역 배수

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).
