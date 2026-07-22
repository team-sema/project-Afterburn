# 적 사망 경로 정리

## 현황

`Enemy`가 `no_health` → `queue_free`를 걸고, `DestroyedComponent`도 `no_health`에서 이펙트 스폰 + free를 한다. 카미카제 Hitbox free는 점수/폭발을 건너뛸 수 있다.

## 목표

단일 파괴 경로(점수 → FX → free)로 통일.
