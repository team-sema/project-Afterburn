# 적

각 적의 의도·역할·확정 규칙은 아래 상세 문서에서 함께 읽는다.
진형 → [formations](../formations/index.md) · 조합 → [encounters](../encounters/index.md) · 언제 → [run-pacing](../run-pacing.md).

## 타입 요약

| 코드명 | 외형 | 최소 Threat | 씬 | HP | 점수 | 상세 |
|--------|------|-------------|-----|-----|------|------|
| Green / Drone | 분홍 네온 다이아몬드 | 1 | `normal_enemy.tscn` | 28 | 5 | [drone](drone.md) |
| Yellow / Striker | 넓은 날개 다이아몬드 | 1 | `moving_enemy.tscn` | 60 | 10 | [striker](striker.md) |
| Awl / Kamikaze | 세로로 긴 송곳 | 1 | `kamikaze_enemy.tscn` | 80 | 15 | [awl](awl.md) |
| Bomb | 원형 본체 + 짧은 신관 | 1 | `bomb_enemy.tscn` | 160 | 20 | [bomb](bomb.md) |
| Interceptor | 주황 네온 화살촉 | 1 | `interceptor_enemy.tscn` | 50 | 5 | [interceptor](interceptor.md) |
| Pink / Caster | 육각·크리스탈형 | 3 | `shooting_enemy.tscn` | 110 | 25 | [caster](caster.md) |
| Sniper | 가느다란 창형 | 3 | `sniper_enemy.tscn` | 95 | 25 | [sniper](sniper.md) |
| Elite Fighter | 대형 다익 포격기 | (타임 게이트) | `elite_fighter.tscn` | Threat 공식 | 40 | [elite-fighter](elite-fighter.md) |
| Elite Awl | 대형 관통 용골 | (교대 타임 게이트) | `elite_awl.tscn` | Threat 공식 | 40 | [elite-awl](elite-awl.md) |

스프라이트는 흰 마스크 SVG를 네온 글로우 레이어로 칠해 쓴다. 상세 문서의 **외형** 절에 미리보기와 설명이 있다.

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
- 현재 스폰 세트에는 보스 적을 넣는 콘텐츠가 **없음** (플래그·배율만 구현) — [gaps](../gaps.md)

## 하위 문서

- [Drone](drone.md)
- [Striker](striker.md)
- [Awl](awl.md)
- [Bomb](bomb.md)
- [Interceptor](interceptor.md)
- [Caster](caster.md)
- [Sniper](sniper.md)
- [Elite Fighter](elite-fighter.md)
- [Elite Awl](elite-awl.md)

## 변경 이력

- 2026-09-14: 타입 요약에 외형 한 줄 · 상세 문서 스프라이트 미리보기 추가.
- 2026-09-13: 주제별 통합 기획서로 이전하고 문서 링크·구현 기준 정리.
- 2026-09-07: 돌격형 Elite Awl 및 교대 엘리트 로스터 추가.
