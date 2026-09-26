# 무기 모듈

무기 **획득**과 무기별 **특성(강화) 모듈**을 정리한다. 함선 시설 슬롯 모듈은 [함선 모듈](../ship-modules/index.md).

## 기획 의도

무기는 베이에서 동시 운용하고, 성장은 그 무기에만 붙는 모듈 카드로만 한다. 모듈은 등급으로 성격을 나눈다. 실버는 기본 스탯을 조금씩 쌓고, 골드는 무기가 하는 일을 바꾸고, 프리즘은 무기의 규칙을 깬다.

## 확정된 현재 동작

- 획득 Kind: `WEAPON_ACQUIRE`(실버) · 모듈 Kind: `WEAPON_TRAIT`
- 모듈은 `WeaponTraitDefinition` (`tier` · `params` Lv.I + `rank_overrides` Lv.II 이상)

| 등급 | 무기당 | 최대 레벨 | 성격 |
|------|--------|-----------|------|
| 실버 | 2 (피해 + 고유 스탯) | V | 부작용 없는 소폭 스탯 강화 |
| 골드 | 3 | III | 동작 변화. 가벼운 대가 가능 |
| 프리즘 | 0~1 | I | 무기 규칙 변화. 큰 대가 |

- 피해 실버 모듈 ID는 `<무기 ID>_power`이며 `damage_mult`를 그 무기의 유효 피해 배율(시설·임시 버프와 같은 채널)에 곱한다. 투사체·빔·폭발·방벽 접촉 피해가 모두 따른다.
- 동일 카드 반복 등장으로 레벨업 · 최대 레벨이면 후보 제외 · 레벨이 없는 프리즘 카드의 제목 둘째 줄은 `<무기> 전용`이다
- 카드 ID = `trait_<trait_id>` · 함선 범용 슬롯 **미사용** · 카드 `tier`는 연결된 모듈 `tier`와 같다.
- 획득·모듈 카드는 모두 **해당 무기 SVG**를 아이콘으로 쓴다 (`assets/weapons/`)
- 오퍼 필터·등급·UI: [오그먼트](../augments.md)
- 특성 설명은 `WeaponTraitDefinition.description` 템플릿에 해당 등급 수치를 채워 만든다. `{키}`는 그 등급의 `params` 값, `{키%}`는 값×100이다. 오퍼 카드·STATUS 미리보기는 다음 등급 수치를 보여 주고, Lv.II 이상은 바뀌는 값을 `현재→다음`으로 표시한다. HUD 모듈 설명은 현재 등급 수치다. 수치는 설명 문자열에 따로 적지 않는다.
- HUD 모듈 육각형은 프리즘→골드→실버 순으로 놓고 테두리 색으로 등급을 구분한다(실버 은청색 · 골드 호박색 · 프리즘 자홍색). 모듈이 4개를 넘으면 육각형을 줄여 4칸 폭 안에 한 줄로 둔다.
- 특성의 지연 동작(버스트 추가 사격, 도탄 판정 재활성 등)은 게임플레이 시계를 따라 트리 일시정지(오그먼트 선택·탄소거) 동안 멈춘다.

## 무기별 문서

| 무기 ID | 아이콘 | 표시명 | 실버/골드/프리즘 | 문서 |
|---------|--------|--------|------------------|------|
| `main_blaster` | ![블래스터](sprites/weapon_main_blaster.svg) | 블래스터 | 2/3/1 | [블래스터](blaster.md) |
| `main_laser` | ![레이저](sprites/weapon_main_laser.svg) | 레이저 | 2/3/0 | [레이저](laser.md) |
| `main_shotgun` | ![샷건](sprites/weapon_main_shotgun.svg) | 샷건 | 2/3/0 | [샷건](shotgun.md) |
| `aux_test_cannon` | ![보조 캐넌](sprites/weapon_aux_cannon.svg) | 보조 캐넌 | 2/3/0 | [보조 캐넌](aux-cannon.md) |
| `plasma_bomb` | ![플라즈마](sprites/weapon_plasma_bomb.svg) | 플라즈마 폭탄 | 2/3/0 | [플라즈마](plasma-bomb.md) |
| `aux_homing_missile` | ![유도탄](sprites/weapon_aux_homing_missile.svg) | 유도탄 | 2/3/0 | [유도탄](homing-missile.md) |
| `aux_orbital_barrier` | ![궤도 방벽](sprites/weapon_aux_orbital_barrier.svg) | 궤도 방벽 | 2/3/0 | [궤도 방벽](orbital-barrier.md) |

합계 획득 7 + 모듈 **36** (실버 14 · 골드 21 · 프리즘 1). 실버 피해 모듈은 Lv.I~V `damage_mult` ×1.08 · 1.16 · 1.24 · 1.32 · 1.40이다. 아이콘은 흰 마스크 SVG를 블루 글로우로 칠해 쓴다. 상세의 **외형** 절에 미리보기가 있다.

## 완료 조건·검증

- 장착 중인 무기의 모듈만 오퍼에 나오고, 최대 레벨 모듈은 제외된다.
- 무기 교체 시 피교체 무기 모듈 레벨(프리즘 포함)은 삭제된다.
- 36개 모듈 설명이 모든 레벨에서 빈 자리 없이 채워지고, Lv.II 이상 카드는 바뀐 값을 `현재→다음`으로 보여 준다. 카드와 모듈의 등급이 같다 (`tests/weapon_module_rank_data_test.gd`).
- 피해 실버 모듈이 그 무기의 유효 피해 배율에만 곱해진다 (`tests/weapon_power_module_test.gd`).
- 오그먼트 선택으로 일시정지된 동안 샷건 버스트 추가 사격이 나가지 않는다 (`tests/weapon_trait_pause_timer_smoke_test.gd`).
