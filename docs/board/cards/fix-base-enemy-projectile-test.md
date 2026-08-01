# 적 기본 탄 스모크 테스트 최신화

## 목표

`tests/base_enemy_projectile_smoke_test.gd`가 캐스터 개편 이전 설계를 검사해 상시 실패하던 것을 현재 구조에 맞춘다.

## 배경

캐스터(`shooting_enemy.tscn`)는 `_enter_tree`에서 기본 `EnemyShootComponent`를 제거하고 `RadialBarrageShootComponent`로 교체한다. 테스트는 씬을 트리에 넣지 않은 상태에서 그 기본 컴포넌트가 `curve_projectile.tscn`을 쓰는지 검사했다. `curve_projectile`은 이미 레거시로 적 사격에서 쓰이지 않으므로(`docs/spec/combat.md`) 검사 자체가 낡았다.

## AC

- [x] 캐스터의 방사 탄막이 `base_enemy_projectile.tscn`을 쓰는지 검사한다
- [x] 트리 진입 후 기본 `EnemyShootComponent`가 제거되는지 검사한다
- [x] 테스트가 PASS로 통과한다
- [x] 기존 직선 탄 검사(레이어·속도·비곡선)는 그대로 유지한다

## 구현

- 2026-08-01 `tests/base_enemy_projectile_smoke_test.gd` 후반 단정 2건 교체
- 2026-08-02 feature/fix-base-enemy-projectile-test → main (검증 대기)
