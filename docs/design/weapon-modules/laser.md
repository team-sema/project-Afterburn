# 무기 모듈 · 레이저

- 무기 ID: `main_laser`
- 획득 카드: `acquire_main_laser`

## 외형

![레이저](sprites/weapon_main_laser.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_main_laser.svg`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 표시명(요지) |
|----------|---------|--------------|
| `laser_wide_lens` | `trait_laser_wide_lens` | 광각 렌즈 — 폭 ×1.8→2.4 · 피해 ×0.9→1.0 |
| `laser_heat_stack` | `trait_laser_heat_stack` | 열 축적 — 스택 +15%→+25% · 최대 +90%→+150% |
| `laser_refract` | `trait_laser_refract` | 굴절 빔 — 보조 빔 피해 55%→85% · 경로 VFX 0.13초 |
| `laser_pulse` | `trait_laser_pulse` | 펄스 발진 — ON 0.7→0.9초 · 피해 ×2→2.5 · OFF 0.35초 |

`laser_heat_stack`의 스택 간격은 `_physics_process` 델타를 누적한 게임플레이 시계로 재므로 트리 일시정지(오그먼트 선택·탄소거) 동안 멈춘다.

## 완료 조건·검증

- 일시정지 중 흐른 시간은 `laser_heat_stack` 스택 간격에 반영되지 않는다.
- `tests/laser_heat_clock_smoke_test.gd` · `tests/laser_pulse_fade_smoke_test.gd`로 확인한다.

상위: [무기 모듈](index.md)
