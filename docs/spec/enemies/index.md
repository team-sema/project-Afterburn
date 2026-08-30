# 적

유닛(무엇을 하는가) — **구현 스펙**.  
의도(왜) → [기획 · 적](../design/#enemies).  
진형 → [formations](#formations) · 조합 → [encounters](#encounters) · 언제 → [run-pacing](#run-pacing).

## 타입 요약

| 코드명 | 최소 Threat | 씬 | HP | 점수 | 상세 |
|--------|-------------|-----|-----|------|------|
| Green / Drone | 1 | `normal_enemy.tscn` | 28 | 5 | [drone](#enemies/drone) |
| Yellow / Striker | 1 | `moving_enemy.tscn` | 60 | 10 | [striker](#enemies/striker) |
| Awl / Kamikaze | 1 | `kamikaze_enemy.tscn` | 80 | 15 | [awl](#enemies/awl) |
| Bomb | 1 | `bomb_enemy.tscn` | 160 | 20 | [bomb](#enemies/bomb) |
| Interceptor | 1 | `interceptor_enemy.tscn` | 50 | 5 | [interceptor](#enemies/interceptor) |
| Pink / Caster | 3 | `shooting_enemy.tscn` | 110 | 25 | [caster](#enemies/caster) |
| Sniper | 3 | `sniper_enemy.tscn` | 95 | 25 | [sniper](#enemies/sniper) |
| Elite Fighter | (타임 게이트) | `elite_fighter.tscn` | Threat 공식 | 40 | [elite-fighter](#enemies/elite-fighter) |

베이스 `enemies/enemy.tscn`: 네온 레이어, 전투/VFX, `TargetingComponent`, `EnemyShootComponent`, `EnemyModifierFactory`, XP 드롭.

## Enemy 베이스 동작

- 생존→사망 시 `no_health` 1회 → 점수 + XP + 기본 파괴 FX + `Enemy` 최종 `queue_free`
- 중복 치명 입력은 사망 보상을 반복하지 않는다. 화면 밖 despawn은 `no_health`를 발생시키지 않아 보상이 없다
- Hurt VFX/SFX · 플레이어 접촉 시 피해만 주고 적은 유지
- **이동:** `Node2D` + `MovementSequence` → `MovementController` → `MoveComponent.translate` (CharacterBody/`move_and_slide` 없음). Sequence가 없는 기존 객체는 `MoveComponent.velocity` 경로를 유지한다.

## EnemyModifierFactory

HEALTH / MOVE_SPEED / ACTION_RATE (+ `EnemyShootComponent` / `RadialBarrageShootComponent` / `SniperAttackComponent` 주기).

## 보스 플래그 (`is_boss`)

- `Enemy.is_boss == true`이면 `bosses` 그룹에 들어가며, 시설 **대형 표적 해석기**(`BOSS_DAMAGE_MULT`) 피해 배율 대상이 된다
- 현재 스폰 세트에는 보스 적을 넣는 콘텐츠가 **없음** (플래그·배율만 구현) — [gaps](#gaps)

## 하위 문서

- [Drone](#enemies/drone)
- [Striker](#enemies/striker)
- [Awl](#enemies/awl)
- [Bomb](#enemies/bomb)
- [Interceptor](#enemies/interceptor)
- [Caster](#enemies/caster)
- [Sniper](#enemies/sniper)
- [Elite Fighter](#enemies/elite-fighter)
