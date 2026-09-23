# 무기 모듈

무기 **획득**과 무기별 **특성(강화) 모듈**을 정리한다. 함선 시설 슬롯 모듈은 [함선 모듈](../ship-modules/index.md).

## 기획 의도

무기는 베이에서 동시 운용하고, 성장은 그 무기에만 붙는 특성 카드(최대 Lv.III)로만 한다.

## 확정된 현재 동작

- 획득 Kind: `WEAPON_ACQUIRE` · 특성 Kind: `WEAPON_TRAIT`
- 특성은 `WeaponTraitDefinition` (`params` Lv.I + `rank_overrides` Lv.II·III)
- 동일 카드 반복 등장으로 레벨업 · Lv.III면 후보 제외
- 카드 ID = `trait_<trait_id>` · 함선 범용 슬롯 **미사용**
- 획득·특성 카드는 모두 **해당 무기 SVG**를 아이콘으로 쓴다 (`assets/weapons/`)
- 오퍼 필터·UI: [오그먼트](../augments.md)

## 무기별 문서

| 무기 ID | 아이콘 | 표시명 | 특성 수 | 문서 |
|---------|--------|--------|---------|------|
| `main_blaster` | ![블래스터](sprites/weapon_main_blaster.svg) | 블래스터 | 4 | [블래스터](blaster.md) |
| `main_laser` | ![레이저](sprites/weapon_main_laser.svg) | 레이저 | 4 | [레이저](laser.md) |
| `main_shotgun` | ![샷건](sprites/weapon_main_shotgun.svg) | 샷건 | 4 | [샷건](shotgun.md) |
| `aux_test_cannon` | ![보조 캐넌](sprites/weapon_aux_cannon.svg) | 보조 캐넌 | 4 | [보조 캐넌](aux-cannon.md) |
| `plasma_bomb` | ![플라즈마](sprites/weapon_plasma_bomb.svg) | 플라즈마 폭탄 | 4 | [플라즈마](plasma-bomb.md) |
| `aux_homing_missile` | ![유도탄](sprites/weapon_aux_homing_missile.svg) | 유도탄 | 4 | [유도탄](homing-missile.md) |
| `aux_orbital_barrier` | ![궤도 방벽](sprites/weapon_aux_orbital_barrier.svg) | 궤도 방벽 | 4 | [궤도 방벽](orbital-barrier.md) |

합계 획득 7 + 특성 **28**. 아이콘은 흰 마스크 SVG를 블루 글로우로 칠해 쓴다. 상세의 **외형** 절에 미리보기가 있다.

## 완료 조건·검증

- 장착 중인 무기의 특성만 오퍼에 나오고, Lv.III는 제외된다.
- 무기 교체 시 피교체 무기 특성 레벨은 삭제된다.
