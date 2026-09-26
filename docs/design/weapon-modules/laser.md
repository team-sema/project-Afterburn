# 무기 모듈 · 레이저

- 무기 ID: `main_laser`
- 획득 카드: `acquire_main_laser`

## 외형

![레이저](sprites/weapon_main_laser.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_main_laser.svg`

## 기본 공격

- 빔은 플레이필드 위쪽 끝까지 닿고, 0.1초 틱마다 빔 판정 폭 안에 걸친 모든 적 피격 부위를 한 번씩 타격한다. 무적 피격 부위는 건너뛴다.
- 판정 폭은 `beam_hit_width` **3px**(시각 글로우 폭과 같음) × 폭 배율이다. 폭 배율은 `beam_width_multiplier` × 광각 렌즈 `width_mult`이며 시각 폭과 판정 폭에 같이 적용한다.

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
- `tests/laser_heat_stack_smoke_test.gd` · `tests/laser_beam_width_smoke_test.gd` · `tests/laser_heat_clock_smoke_test.gd` · `tests/laser_pulse_fade_smoke_test.gd`로 확인한다.

상위: [무기 모듈](index.md)
