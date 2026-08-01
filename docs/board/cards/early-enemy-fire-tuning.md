# 초반 적 사격 완화

## 목표

초반(Threat 1) 적의 투사체 빈도와 탄속을 낮춰 진입 난이도를 완화한다.

## 배경

플레이 피드백: 초반이 너무 어렵다. Threat 1 로스터 중 투사체를 쓰는 적은 Drone(5기 편대)과 Striker뿐인데, Drone은 탄속 150으로 회피 여유가 적고 Striker는 3볼리 × 5발(15발)을 3초마다 부채꼴로 뿌려 시작 구간 압력이 과했다.

## 변경

| 적 | 항목 | 이전 → 이후 |
|---|---|---|
| Drone | `fire_interval` | 3.0 → 4.5 |
| Drone | `projectile_speed` | 150 → 105 |
| Drone | `initial_delay` | 1.0 → 1.5 |
| Striker | `fire_interval` | 3.0 → 4.5 |
| Striker | `burst_count` | 3 → 2 |
| Striker | `projectile_speed` | 100(기본) → 80 |
| Striker | `initial_delay` | 0.75(기본) → 1.5 |

발수(`shot_count` 5)와 부채꼴 각(15°)은 Striker의 식별 가능한 공격 형태라 유지했다.

## AC

- [x] Drone·Striker의 사격 주기가 길어지고 탄속이 느려진다
- [x] 스폰 직후 첫 사격까지 여유가 생긴다 (`initial_delay` 1.5)
- [x] Caster(Threat 3)와 Kamikaze·Bomb 동작은 건드리지 않는다
- [x] 적 오그먼트 `ACTION_RATE` 후반 상승 경로는 그대로 유지된다
- [x] `docs/spec/enemies.md`에 초반 사격 압력 수치를 명시한다
- [ ] 사람 플레이 검증: 초반 회피 여유가 충분한지 확인

## 구현

- 2026-08-01 `enemies/normal_enemy.tscn`, `enemies/moving_enemy.tscn` 사격 오버라이드 조정, `docs/spec/enemies.md` 갱신
- 2026-08-02 feature/early-enemy-fire-tuning → main (검증 대기)
