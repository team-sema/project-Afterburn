# 무기 모듈 · 보조 캐넌

- 무기 ID: `aux_test_cannon`
- 획득 카드: `acquire_aux_test_cannon`

## 외형

![보조 캐넌](sprites/weapon_aux_cannon.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_aux_cannon.svg`
- 타격 이펙트: [공용 규칙](../effects.md#타격-이펙트) · 프로필 `effects/impact_profiles/aux_cannon.tres`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 등급 | 표시명(요지) |
|----------|---------|------|--------------|
| `aux_auto_loader` | `trait_aux_auto_loader` | 실버 | 자동 급탄 — 연사 간격 ×0.93→0.71 |
| `aux_test_cannon_power` | `trait_aux_test_cannon_power` | 실버 | 화력 보정 — 피해 ×1.08→1.40 |
| `aux_heavy_barrel` | `trait_aux_heavy_barrel` | 골드 | 편대 증설 프레임 — 드론 +2 · 드론당 피해 ×0.7→0.9 |
| `aux_he_shell` | `trait_aux_he_shell` | 골드 | 고폭 탄두 — 직격 ×0.95 · AOE 80%→100% · 반경 28→44 |
| `aux_hv_ap` | `trait_aux_hv_ap` | 골드 | 고속 철갑 — 피해 ×1.1→1.3 · 탄속 ×1.6→2.0 · 관통 +3→+5 |
| `aux_autonomous_prism` | `trait_aux_autonomous_prism` | 프리즘 | 자율 편대 — 드론이 적 주위를 돌며 조준 사격 · 드론당 피해 ×0.75 |

실버 수치는 Lv.I→V, 골드는 Lv.I→III이다.

### 자율 편대 (프리즘)

- 드론이 함선 옆 고정 자리를 떠나 화면 안의 적을 하나씩 맡는다. 맡은 적이 살아서 화면 안에 있는 동안은 바꾸지 않는다. 새로 고를 때는 드론이 가장 적게 붙은 적 중 그 드론에서 가장 가까운 적을 고른다.
- 드론은 맡은 적 주위 반경 `orbit_radius` **44px**를 초당 `orbit_speed` **1.4rad**로 돌고, 이동 속도는 `drone_speed` **160px/s**다. 같은 적을 맡은 드론끼리는 같은 간격으로 둘러선다. 목표 위치는 플레이필드 안쪽 6px까지로 제한한다.
- 사격은 드론 위치에서 맡은 적 방향으로 나가고, 드론도 그 방향을 바라본다. 적이 없으면 원래 자리로 돌아와 위로 쏜다.
- 드론 수(편대 증설 프레임 포함)·연사·고폭 탄두·고속 철갑은 그대로 적용한다. 드론당 피해 ×`damage_mult` **0.75**.
- 대가: 드론당 피해가 줄고, 드론이 함선 곁을 떠나 정면 화력이 비게 된다.

## 완료 조건·검증

- 자율 편대를 장착하면 드론이 화면 안의 적 주위로 이동해 그 적 방향으로 쏘고, 적이 없으면 원래 자리에서 위로 쏜다 (`tests/prism_weapon_modules_test.gd`).

상위: [무기 모듈](index.md)
