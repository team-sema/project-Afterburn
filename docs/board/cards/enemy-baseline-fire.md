# 적 기본 사격 · 포화 위기

## 목표

- 모든 적이 기본으로 조준 탄환을 발사한다.
- 적 위기(반격)는 On-Hit 반격 대신 **더 자주·더 많은 탄**으로 바꾼다.
- 기본 이동 속도를 소폭 올린다.

## 구현

- `EnemyShootComponent`를 베이스 `enemy.tscn`에 부착
- 풀: `enemy_counter_shot_on_hit` → `enemy_fire_volume_boost` (ACTION_RATE ×1.25 + volley)
- Green `(0,46)` / Yellow Y12 ±23X / Pink state 속도·duration 조정
- 2026-07-30 `feature/enemy-baseline-fire` → main (검증 대기)
