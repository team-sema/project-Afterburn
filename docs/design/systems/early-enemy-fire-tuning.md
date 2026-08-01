# 초반 적 사격 완화

## 문제

플레이 피드백: 초반이 너무 어렵다. Threat 1 로스터에서 투사체를 쓰는 적은 Drone(5기 편대)과 Striker뿐인데 둘 다 시작 구간 압력이 과했다.

- Drone: 탄속 150 · 주기 3.0 · 첫 사격 1.0초 → 5기가 동시에 조준 사격해 회피 여유가 짧다
- Striker: 주기 3.0에 3볼리 × 5발(15°) = **한 사이클 15발** → Threat 1에 어울리지 않는 물량

## 규칙

1. 초반 압력은 **씬 오버라이드 수치**로만 조정한다. `EnemyShootComponent` 로직과 적 오그먼트 상승 경로는 바꾸지 않는다.
2. Drone·Striker의 사격 **주기를 늘리고 탄속을 낮춘다**. 스폰 직후 첫 사격까지 `initial_delay` 1.5초를 준다.
3. Striker의 `shot_count` 5와 `spread_degrees` 15°는 **유지**한다. 부채꼴 형태가 그 적의 식별 요소다. 물량은 `burst_count`로만 줄인다.
4. Caster(Threat 3)·Kamikaze·Bomb은 건드리지 않는다. 앞의 둘은 투사체가 없고 Caster는 초반에 등장하지 않는다.
5. 후반 난이도는 기존 경로(적 오그먼트 `ACTION_RATE`가 `fire_interval`·`burst_interval`을 나눔, 상위 Threat 적 합류)로 오른다. 탄속에는 배율이 없으므로 이 두 적의 탄속은 런 내내 낮은 값을 유지한다.

## 수치

| 적 | 항목 | 이전 → 이후 |
|---|---|---|
| Drone | `fire_interval` | 3.0 → 4.5 |
| Drone | `projectile_speed` | 150 → 105 |
| Drone | `initial_delay` | 1.0 → 1.5 |
| Striker | `fire_interval` | 3.0 → 4.5 |
| Striker | `burst_count` | 3 → 2 |
| Striker | `projectile_speed` | 100(기본) → 80 |
| Striker | `initial_delay` | 0.75(기본) → 1.5 |

임시 밸런스 값이며 사람 플레이 검증 후 조정 대상이다.

## AC

- [x] Drone·Striker의 사격 주기가 길어지고 탄속이 느려진다
- [x] 스폰 직후 첫 사격까지 1.5초 여유가 있다
- [x] Striker의 발수·부채꼴 각이 유지된다
- [x] Caster·Kamikaze·Bomb 동작이 변하지 않는다
- [x] `ACTION_RATE` 상승 경로가 그대로 동작한다
- [x] `docs/spec/enemies.md`가 새 수치와 일치한다
- [ ] 사람 플레이 검증: 초반 회피 여유가 충분한지 확인

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-01 | 초안 · Drone·Striker 주기·탄속·첫 사격 지연 완화 |
