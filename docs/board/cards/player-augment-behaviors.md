# 플레이어 오그먼트 behavior 적용

## 현황

`PlayerAugment.behavior_components`는 Resource에 있지만 `PlayerAugmentApplier`는 스탯 배수만 적용한다. 적 쪽 `EnemyModifierFactory`는 behavior를 붙인다.

## 목표

플레이어 오그먼트 선택 시 PackedScene behavior를 Ship(또는 지정 마운트)에 인스턴스하고, clear 시 정리.

## 참고

- `components/player_augment_applier.gd`
- `resources/player_augments/player_augment.gd`
- 스펙: `docs/spec/augments.md`, `docs/spec/gaps.md`
