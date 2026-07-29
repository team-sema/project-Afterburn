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
- 오브 비주얼: 황금 글로우 사각 보급상자 (`pickups/experience_orb.tscn`, `assets/svg/supply_crate.svg`)
- Collector 중심 근처에서 XP를 지급하며 PlayerHitPoint와 독립

## PlayerHitPoint

- 코어 히트 반경(기본 **3px**)
- Hurtbox CollisionShape + 비주얼 스케일
- 플레이어 Hurtbox 위치 (기본 **layer 1** `player_hurtbox`)

## 무기 (슬롯 무장)

- `PlayerWeaponLoadout`: 주무기 1 + 보조 최대 3 (시작 시 보조 슬롯 3개 모두 해금·빈칸)
- 시작 주무기: 블래스터 (무기 Lv.1), 슬롯 Lv.1
- **주무기 필드 픽업**: 해당 **무기 ID 레벨** 상승·보존 (스왑해도 유지). 슬롯 레벨과 별개
- **보조무기**: 소모품. **자체 레벨 없음**. 동일 픽업 = 사용량 리필, 소진 시 슬롯 제거
- **슬롯 강화**: 오그먼트 `UPGRADE_*`만. 픽업으로 슬롯 레벨이 오르지 않음
- 다른 주무기 → 무기 레벨 반영 후 교체 확인 (거부해도 레벨은 유지, 픽업 소멸)
- 보조 → 빈칸 장착 / 가득 차면 교체 UI
- 주무기 최종 배율 = 플레이어 공통 × **슬롯** × **무기** / 보조 = 공통 × **슬롯**
- 궤도 방벽 조각은 피격 시 영구 파괴(재생 없음). 전량 파괴 시 슬롯 소모

## PlayerAugmentApplier

`augment_added` / `augments_cleared` / `refresh()` 시:

- `MOVE_SPEED` → `MoveComponent.velocity_multiplier`
- `FIRE_RATE` / `WEAPON_DAMAGE` → 각 WeaponSystem 전역 배수
- `UPGRADE_*` → 슬롯 오버클럭 (성능). 장착/해금 타입은 무시

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).
