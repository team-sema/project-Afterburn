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

- `PlayerWeaponLoadout`: 주무기 **메인(발사) + 예비** + 보조 최대 3
- 시작 주무기: 블래스터가 메인 슬롯 (무기 Lv.1), 예비 빈칸, 슬롯 Lv.1
- 주무기 후보: 블래스터 · 레이저 · **샷건**(부채꼴 5펠릿)
- **주무기 필드 픽업**: 무기 ID 레벨 상승·보존. 새 무기면 **예비 슬롯 교체**(확인 UI 없음). **X**로 미보유 주무기 픽업 차단 토글
- **Z**: 메인 ↔ 예비 스왑 (예비 비어 있으면 무시)
- **보조무기**: 소모품. **자체 레벨 없음**. 동일 픽업 = 사용량 리필, 소진 시 슬롯 제거
- **슬롯 강화**: 오그먼트 `UPGRADE_*`만. 픽업으로 슬롯 레벨이 오르지 않음
- 주무기 최종 배율 = 플레이어 공통 × **슬롯** × **무기** / 보조 = 공통 × **슬롯**
- 궤도 방벽 조각은 피격 시 영구 파괴(재생 없음). 전량 파괴 시 슬롯 소모

## PlayerAugmentApplier

`augment_added` / `augments_cleared` / `refresh()` 시:

- `MOVE_SPEED` → `MoveComponent.velocity_multiplier`
- `FIRE_RATE` / `WEAPON_DAMAGE` → 각 WeaponSystem 전역 배수
- `UPGRADE_*` → 슬롯 오버클럭 (성능). 장착/해금 타입은 무시

> `PlayerAugment.behavior_components`는 **적용하지 않음** (적 쪽만 동작).
