# 탄 물리 레이어 3·4 정리

## 현황

`project.godot`에 `player_projectile` / `enemy_projectile` 이름이 있으나 실제 탄 Hitbox는 layer 0 + hurtbox mask 패턴이다.

## 선택지

1. 레이어 이름을 제거하고 문서만 mask 패턴으로 통일
2. 탄을 3/4에 올리고 mask를 정리해 충돌 그래프를 명확히

## 참고

- `docs/spec/combat.md`
