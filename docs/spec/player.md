# 플레이어

## Ship (`player_ship/ship.gd`)

- 그룹: `"player"`
- `PlayerAugmentRegistry` 주입 → `PlayerAugmentApplier.initialize`
- `WeaponMount` 아래 모든 `WeaponSystem` 수집
- 무기 `fired` → `ScaleComponent.tween_scale()`

### 주요 자식

Move / MoveInput / PositionClamp / WeaponMount(Blaster+Laser) / PlayerAugmentApplier / Scale / Stats(**HP 1**) / ExperienceCollector / PlayerHitPoint / Hurt / ExplosionSpawner / Destroyed

## ExperienceCollector

- 기본 수집 반경 **36px** (`collection_radius`)
- XP 오브가 범위에 들어오면 바깥으로 짧게 튕긴 뒤 플레이어에게 가속
- Collector 중심 근처에서 XP를 지급하며 PlayerHitPoint와 독립

## PlayerHitPoint

- 코어 히트 반경(기본 **3px**)
- Hurtbox CollisionShape + 비주얼 스케일
- 플레이어 Hurtbox 위치 (기본 **layer 1** `player_hurtbox`)

## 무기 (슬롯 무장)

- `PlayerWeaponLoadout`: 주무기 1 + 보조 최대 3 (시작 시 보조 슬롯 3개 모두 해금·빈칸)
- 시작 주무기: 블래스터 Lv.1
- **획득**: 적 드롭 픽업 (`WeaponAcquisitionController`). 오그먼트로 무기 지급하지 않음
- 동일 무기 픽업 → 해당 슬롯 강화 (최대 Lv.3, 불가 시 아이템 유지)
- 다른 주무기 → 교체 확인 / 보조 빈칸 자동 장착 / 가득 차면 교체 UI
- 무기 교체 시 해당 슬롯 레벨은 1로 리셋. 최종 배율 = 플레이어 공통 × 슬롯

## PlayerAugmentApplier

`augment_added` / `augments_cleared` / `refresh()` 시:

- `MOVE_SPEED` → `MoveComponent.velocity_multiplier`
- `FIRE_RATE` / `WEAPON_DAMAGE` → 각 WeaponSystem 전역 배수
- `UPGRADE_*` → 슬롯 오버클럭 (성능). 장착/해금 타입은 무시

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).
