# 전투

## 기획 의도

작은 피격 코어와 일관된 피격·실드 규칙으로 회피의 성공과 실패를 명확히 전달한다. 엘리트 처치 보상은 탄막 회피 구간에서 다음 선택으로 넘어가는 휴지기를 만든다.

## 확정된 현재 동작

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
  → 생존→사망 전환이면 no_health 1회 → 파괴/점수
```

레이저는 Area 겹침을 쓰지 않고 RayCast + DamageTickTimer로 `hurt`를 직접 보낸다.

`HurtComponent.shield_component`는 플레이어에만 연결돼 있다(적은 null → 기존 동작). **플레이어가 맞는 피해는 항상 1.** 실드는 버퍼 HP라 실드 0일 때만 선체가 깎인다. 모든 피격 후 기본 0.6초 무적이며, 충격 분산 골격은 선체 피격 무적시간을 1.0초 늘려 총 1.6초로 만든다.

## 탄

| 씬 | 역할 |
|----|------|
| `player_blaster.tscn` | 속도 `(0,-200)` · 히트 시 free |
| `player_shotgun_pellet.tscn` | 샷건 펠릿 · 부채꼴 · damage **4** |
| `base_enemy_projectile.tscn` | 적 기본 조준 탄 · `launch(dir, speed)` · 그룹 `enemy_projectiles` |
| `curve_projectile.tscn` | 레거시 곡선 탄 (Anchor 오실레이션) · 기본 사격에서는 미사용 |

### 일반 적 사격 안전선

- `EnemyAugmentRegistry.shot_threshold_y_ratio`의 기본값 **0.7**을 플레이필드 공통 Y 안전선으로 사용한다.
- `EnemyShootComponent.apply_shot_threshold`가 켜진 적은 중심점 Y가 `VisibleRect` 높이의 70%를 넘으면 발사하지 않는다. 즉 상단 70%에서는 발사할 수 있고 하단 30%에서는 발사하지 않는다. 값이 작을수록 더 위에서 사격을 멈춘다.
- Drone · Striker · 이를 상속한 Interceptor가 안전선을 사용한다. Elite 및 Caster/Sniper 전용 공격은 사용하지 않는다.
- 안전선은 볼리 생성 직전에 매번 공통값을 읽는다. 런타임에 공통값이 바뀌면 이미 활성화된 적용 대상도 다음 발사부터 새 값을 사용한다.

### 엘리트 이상 처치 탄소거

- Threat 엘리트 처치 시 전투를 일시정지하고 플레이필드의 `enemy_projectiles`를 즉시 제거한다. 플레이어 탄환은 제거하지 않는다.
- 제거한 적탄 1발마다 XP 1짜리 `ExperienceOrb`를 탄 위치에 생성한다.
- 엘리트의 확정 드롭을 포함해 플레이필드에 있던 모든 XP 오브를 플레이어 수집기로 강제 흡수한다. 강제 흡수는 일시정지 중에도 이동하며, 전부 실제 XP로 정산될 때까지 기다린다.
- 흡수 중에는 플레이어 오그먼트 `C` 입력과 HUD 힌트를 잠근다. 흡수가 끝난 뒤 Threat를 올리고 적 오그먼트 오퍼를 연다.
- 보스 스폰·진행은 아직 미구현이다. 향후 보스 처치 흐름도 같은 `BulletCancelRewardController`를 호출해 동일한 탄소거·XP 회수 계약을 사용한다.

## 점수·난이도 상수

| 이벤트 | 값 |
|--------|-----|
| Pink 해금 | score > 50 |
| Green / Yellow / Pink / Awl / Bomb 점수 | 5 / 10 / 25 / 15 / 20 |

> 플레이어 오그먼트는 **점수 임계가 아니라 XP + C 키**. 적 오그먼트는 60초마다 등장하는 엘리트를 처치한 뒤 선택.

## 완료 조건·검증

- 플레이어 피해는 피격당 1이며 실드가 먼저 소모된다.
- 중복 치명 입력으로 점수·XP가 중복 지급되지 않는다.
- 엘리트 처치 시 적탄만 XP로 바꾸고 정산 완료 전 다음 오퍼를 열지 않는다.

검증 참고: `tests/bullet_cancel_reward_smoke_test.gd`. Godot 실행은 `tools/run-godot.cmd`를 사용한다.


## 변경 이력

- 2026-09-13: 주제별 통합 기획서로 이전하고 문서 링크·구현 기준 정리.
