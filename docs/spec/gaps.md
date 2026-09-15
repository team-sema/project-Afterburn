# 갭 · 확장 포인트

구현은 됐지만 **미연결·미사용·중복**인 지점. Notion [아이템 칸반](https://app.notion.com/p/102c71bf78394bcaa9ff627548faf7f9?v=3c9b8c11155f8111bfeb000c00cae3b8) 백로그 후보와 대응한다.

대조 기준: 2026-09-15 · 게임 코드(`feature/encounter-sequence` 포함).

## 기능 갭

1. **`PlayerAugment.behavior_components`** — 필드만 있고 `PlayerAugmentApplier`가 부착하지 않음. 적 쪽은 `EnemyModifierFactory`가 사용
2. **`EnemyAugmentGrantComponent`** — API 완비, 씬 사용 0
3. **물리 레이어 3–4** — `project.godot`에 `player_projectile` / `enemy_projectile` **이름만**. 탄 Hitbox는 대개 layer 0 + hurtbox mask (`docs/spec/combat.md`)
4. **`clear_augments()`** — 레지스트리 API만 있고 게임오버·재시작 경로에서는 미호출(씬 전환에 의존). 테스트에서만 호출
5. **부위·모듈 밸런스 수치** — `FacilityModuleEffect` primary 등은 플레이스홀더 성격. 기본 선체 1
6. **보스 콘텐츠** — `Enemy.is_boss` / `bosses` · 보스 피해 배율 · 엘리트 이상 공용 `BulletCancelRewardController`는 있음. **전용 보스 씬·패턴·밸런스는 없음**. Encounter 시퀀스 BOSS 스텝은 `is_boss` 게이트만 연결 가능
7. **우측 패널 세로 여유** — 항목 추가 전 동적 fit 검사를 먼저 확인

## 구조 이슈

8. 파일명 typo: `timed_state_componoent.gd`
9. `OnetimeAnimatedEffect` vs `neon_explosion` 이원화
10. `ResourceStash` Autoload는 **게임 코드에서 참조 0** — GameStats는 씬 `@export`로 주입. 사용하거나 제거할지 미결
11. highscore만 런 간 유지, 오그먼트 레지스트리는 비영속
12. **그룹 기반 런타임 조회** — `get_first_node_in_group`이 약 15개 파일에서 `gameplay_world`·`augment_progression`·`player` 등을 찾음. 등록 누락이 조용한 실패가 되고 테스트마다 수동 `add_to_group` 필요
13. **무기 trait `.tres` 이원화** — `resources/weapons/traits/`(무기 코드가 경로 로드)와 `resources/player_augments/weapon/trait_*.tres`(오퍼 풀)에 같은 특성 **각 28** 중복
14. **루트에 게임 코드 10개** — 오퍼/진행/레지스트리·`enemy_generator.gd`·`threat_elite_controller.gd`·`resource_stash.gd`·`world*.gd` 등 (짝 씬은 `enemies/` 등)
15. **테스트 공용 베이스 없음** — 약 **59**개 테스트가 `_expect`와 긴 씬 경로를 각자 하드코딩. `AGENTS.md` 예시 `tests/example_test.gd`는 실재하지 않음
16. **`3d/physics_engine="Jolt Physics"`** — 2D 전용 프로젝트에 남은 사문 설정
17. **일반 적 사격 안전선 소유권** — 공통 0.7 값은 런 공유·즉시 반영을 위해 `EnemyAugmentRegistry`에 있음. 전역 전투 옵션·threshold 증강 추가 시 authored 기본값은 `EnemyCombatConfig`로 분리하고 Registry에는 런타임 보정만 둔다. 개별 연사·탄수·탄속·패턴은 각 공격 컴포넌트에 유지

## 해결됨 (기록)

| 과거 항목 | 상태 |
|-----------|------|
| `EnemyStatModifier.ACTION_RATE` | `enemy_fire_volume_boost`로 풀 연결 (사격 주기 + TimedState) |
| 오그먼트 풀 가중치 | **현행 설계** — `offer_weight` × 범주 배율. 정본 `docs/spec/augments.md` |
| `gameplay.tscn` 인라인 증강 풀 | `AugmentPoolLoader` 폴더 스캔으로 이전 |
| Enemy `no_health` 이중 free/이펙트 | Enemy가 `DestroyedComponent.auto_destroy_on_no_health = false`로 점수→이펙트→`queue_free` 소유 |
| 카미카제 Hitbox free → 점수 스킵 | 접촉 Hitbox는 피해만. 본체 free로 점수 경로를 건너뛰지 않음 |

## 콘텐츠 확장 아이디어

- **보스** 전용 적·패턴·처치 연출 (게이트/플래그 인프라는 부분 존재)
- 플레이어 행동 오그먼트 (대시 등) — `behavior_components` 연결 포함
- **설정 메뉴** (볼륨 등) — ESC 일시정지는 있음, 설정 UI는 미완
- 복잡한 무기 trait(도탄·잔류장 등) 플레이 밸런스 튜닝
- Threat/Encounter 로스터·시퀀스 확장 시 `docs/spec/run-pacing.md`와 동기화

## 변경 이력

- 2026-09-15: 해결 항목 분리 · 레이어 3–4·카운트·보스 설명 코드 대조로 최신화.
