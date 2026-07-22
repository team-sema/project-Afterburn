# ACTION_RATE 적 오그먼트 에셋

## 현황

`EnemyModifierFactory`는 `EnemyStatModifier.Stat.ACTION_RATE`로 `TimedStateComponent.duration`을 나눈다. 그런데 해당 `.tres`가 풀에 없다.

## 목표

- `enemy_*_action_rate_*.tres` 추가
- World `AugmentOfferController` 적 풀에 등록 (choices ≥ 3 유지)

## 참고

- `components/enemy_modifier_factory.gd`
- `resources/enemy_augments/`
