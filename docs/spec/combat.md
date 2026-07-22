# 전투

## 물리 레이어 이름 (`project.godot`)

| Bit | 이름 |
|-----|------|
| 1 | `player_hurtbox` |
| 2 | `enemy_hurtbox` |
| 3 | `player_projectile` |
| 4 | `enemy_projectile` |

**레이어 3–4는 미사용.** 탄 Hitbox는 대개 layer 0 + hurtbox **mask**로 동작한다.

## 레이어/마스크 실사용

| 액터 | Layer | Mask |
|------|-------|------|
| Player Hurtbox | 1 | default |
| Enemy Hurtbox | 2 | 0 |
| Enemy Hitbox (몸) | 0 | 1 |
| Player Blaster Hitbox | 0 | 2 · damage **10** |
| Curve/Counter 탄 | 0 | 1 |
| Laser RayCast | — | 2 (직접 `hurt.emit`) |

## 데미지 파이프라인

```text
Hitbox.area_entered
  → Hurtbox & not invincible
  → hit_hurtbox + hurtbox.hurt
  → HurtComponent: stats.health -= damage
  → no_health → 파괴/점수
```

레이저는 Area 겹침을 쓰지 않고 RayCast + DamageTickTimer로 `hurt`를 직접 보낸다.

## 탄

| 씬 | 역할 |
|----|------|
| `player_blaster.tscn` | 속도 `(0,-200)` · 히트 시 free |
| `curve_projectile.tscn` | 적/반격 · `launch(dir, speed)` · Anchor 오실레이션 |

## 점수·난이도 상수

| 이벤트 | 값 |
|--------|-----|
| 첫 오그먼트 오퍼 | 10 |
| 이후 오퍼 간격 | 100 |
| Pink 해금 | score > 50 |
| Green / Yellow / Pink 점수 | 5 / 10 / 20 |
