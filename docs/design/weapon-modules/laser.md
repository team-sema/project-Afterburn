# 무기 모듈 · 레이저

- 무기 ID: `main_laser`
- 획득 카드: `acquire_main_laser`

## 외형

![레이저](sprites/weapon_main_laser.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_main_laser.svg`

### 빔·피격 연출

- 빔 본체는 `CoreLine`(흰 1px 코어) 위에 `GlowLine` 스프라이트를 `effects/laser_beam.gdshader`로 그린다. 시각 전체 폭은 **20px** × 폭 배율이다.
  - 밝은 근접 글로우(중심 ±약 1.5px)와 옅은 외곽 확산광(알파 최대 0.12)을 한 셰이더에서 합성한다. 판정 폭은 근접 글로우까지이고 외곽 확산광은 시각 전용이다.
  - 에너지 줄무늬가 간격 **26px**, 길이 **10px**, 초당 **420px**로 총구에서 위로 흐른다. 줄무늬마다 밝기가 다르고 일부는 비어 불규칙하게 보인다.
  - 폭이 약 23Hz로 ±8% 떨린다. 빔 끝 10px은 서서히 사라진다.
  - 셰이더의 `beam_length`·`beam_time`은 스크립트가 게임플레이 시계로 매 물리 프레임 갱신하므로 트리 일시정지 동안 흐름이 멈춘다.
- 타격 이펙트는 공용 [타격 이펙트](../effects.md#타격-이펙트) 규칙을 따른다(프로필 `laser`). 데미지 틱마다 빔에 맞은 피격 부위의 빔 중심선 접점에서 아래(함선 쪽)로 튄다.
  - 굴절 보조 빔 착탄점은 강도 **0.6**으로, 굴절 출발점 쪽으로 튄다.
  - 펄스 OFF처럼 피해가 없는 틱에는 표시하지 않는다.
- 펄스 페이드와 오버차지 틴트는 빔 셰이더에도 `self_modulate`로 그대로 적용된다.

## 기본 공격

- 빔은 플레이필드 위쪽 끝까지 닿고, 0.1초 틱마다 빔 판정 폭 안에 걸친 모든 적 피격 부위를 한 번씩 타격한다. 무적 피격 부위는 건너뛴다.
- 판정 폭은 `beam_hit_width` **3px**(빔 셰이더의 밝은 근접 글로우 폭과 같음) × 폭 배율이다. 폭 배율은 `beam_width_multiplier` × 광각 렌즈 `width_mult`이며 시각 폭과 판정 폭에 같이 적용한다.

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 등급 | 표시명(요지) |
|----------|---------|------|--------------|
| `laser_wide_lens` | `trait_laser_wide_lens` | 실버 | 광각 렌즈 — 시각·판정 폭 ×1.2→2.0 |
| `main_laser_power` | `trait_main_laser_power` | 실버 | 집광 코일 — 피해 ×1.08→1.40 |
| `laser_heat_stack` | `trait_laser_heat_stack` | 골드 | 열 축적 — 스택 +15%→+25% · 최대 +90%→+150% |
| `laser_refract` | `trait_laser_refract` | 골드 | 굴절 빔 — 보조 빔 피해 55%→85% · 경로 VFX 0.13초 |
| `laser_pulse` | `trait_laser_pulse` | 골드 | 펄스 발진 — ON 0.7→0.9초 · 피해 ×2→2.5 · OFF 0.35초 |

실버 수치는 Lv.I→V, 골드는 Lv.I→III이다.

`laser_heat_stack`은 같은 적을 연속 조사한 시간 `stack_interval` **0.5초**마다 `stack_bonus`를 더하며 `max_bonus`에서 멈춘다. 첫 피격은 보너스 0이다. 피격 간격이 `contact_grace` **0.5초** 이하면 연속으로 보고 그 사이 시간도 축적에 넣으므로, 펄스 OFF(0.35초)나 굴절 2차 광선 피격도 연속을 유지한다. 간격이 0.5초를 넘으면 다음 피격에서 0부터 다시 쌓는다. 시간은 `_physics_process` 델타를 누적한 게임플레이 시계로 재므로 트리 일시정지(오그먼트 선택·탄소거) 동안 멈춘다.

## 완료 조건·검증

- 연속 조사 0.5초마다 열 축적 보너스가 오르고(Lv.I 3초에 +90%), 0.5초 넘게 끊기면 초기화된다.
- 일시정지 중 흐른 시간은 `laser_heat_stack` 스택 간격에 반영되지 않는다.
- 빔 중심에서 비켜난 적도 판정 폭 안이면 맞고, 광각 렌즈를 장착하면 판정 폭이 넓어진다.
- 빔 셰이더는 빔 길이와 게임플레이 시계를 받아 흐르고, 적을 맞힌 틱마다 피격 부위별로 섬광이 하나씩 생긴다.
- `tests/laser_heat_stack_smoke_test.gd` · `tests/laser_beam_width_smoke_test.gd` · `tests/laser_heat_clock_smoke_test.gd` · `tests/laser_pulse_fade_smoke_test.gd` · `tests/laser_startup_visual_smoke_test.gd` · `tests/laser_beam_shader_smoke_test.gd`로 확인한다.

상위: [무기 모듈](index.md)
