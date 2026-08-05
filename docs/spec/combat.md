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
| Player Shotgun Pellet | 0 | 2 · damage **4** × 5발 |
| Curve/Counter 탄 | 0 | 1 |
| Laser RayCast | — | 2 (직접 `hurt.emit`) |

## 데미지 파이프라인

```text
Hitbox.area_entered
  → Hurtbox & not invincible
  → hit_hurtbox + hurtbox.hurt
  → HurtComponent
      → (player) incoming = 1
      → notify_hit (실드 충전 게이지 리셋)
      → 실드에 먼저 피해 적용, 남은 피해만 stats.health -= remaining
  → no_health → 파괴/점수
```

레이저는 Area 겹침을 쓰지 않고 RayCast + DamageTickTimer로 `hurt`를 직접 보낸다.

`HurtComponent.shield_component`는 플레이어에만 연결돼 있다(적은 null → 기존 동작). **플레이어가 맞는 피해는 항상 1.** 실드는 버퍼 HP라 실드 0일 때만 선체가 깎인다. 기본 피격 무적시간은 없다(충격 분산 골격 모듈만 예외) — 같은 프레임의 다른 히트박스는 별개 이벤트다.

## 탄

| 씬 | 역할 |
|----|------|
| `player_blaster.tscn` | 속도 `(0,-200)` · 히트 시 free |
| `player_shotgun_pellet.tscn` | 샷건 펠릿 · 부채꼴 · damage **4** |
| `base_enemy_projectile.tscn` | 적 기본 조준 탄 · `launch(dir, speed)` · 그룹 `enemy_projectiles` |
| `curve_projectile.tscn` | 레거시 곡선 탄 (Anchor 오실레이션) · 기본 사격에서는 미사용 |

## 점수·난이도 상수

| 이벤트 | 값 |
|--------|-----|
| Pink 해금 | score > 50 |
| Green / Yellow / Pink / Awl / Bomb 점수 | 5 / 10 / 25 / 15 / 20 |

> 플레이어 오그먼트는 **점수 임계가 아니라 XP + C 키**. 적 오그먼트는 플레이 시간 60초 간격.
