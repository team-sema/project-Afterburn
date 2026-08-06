# 갭 · 확장 포인트

구현은 됐지만 **미연결·미사용·중복**인 지점. 칸반 백로그 후보와 대응한다.

## 기능 갭

1. **`PlayerAugment.behavior_components`** — 필드만 있고 Applier가 부착하지 않음
2. **`EnemyAugmentGrantComponent`** — API 완비, 씬 사용 0
3. **`EnemyStatModifier.ACTION_RATE`** — `enemy_fire_volume_boost`로 풀 연결됨 (사격 주기 + TimedState)
4. **물리 레이어 3–4** — 이름만, 탄은 layer 0
5. **`clear_augments()`** — 미호출 (씬 리로드에 의존)
6. **오그먼트 풀 가중치** — `gameplay.tscn` 하드코드 + `offer_weight`. 범주 % 밸런스 미정
7. **부위·모듈 밸런스 수치** — `FacilityModuleEffect` primary 등은 플레이스홀더 성격. 기본 선체 1
8. **보스 콘텐츠** — `Enemy.is_boss` / `bosses` 그룹·보스 피해 배율만 있음. 보스 스폰·패턴 없음
9. **우측 패널 세로 여유** — 항목 추가 전 동적 fit 검사를 먼저 확인

## 구조 이슈

10. Enemy `no_health` → `queue_free`와 `DestroyedComponent` **이중 free/이펙트**
11. 카미카제 Hitbox free가 점수/폭발 순서를 건너뛸 수 있음
12. 파일명 typo: `timed_state_componoent.gd`
13. `OnetimeAnimatedEffect` vs `neon_explosion` 이원화
14. `ResourceStash` Autoload는 **게임 코드에서 참조 0** — GameStats는 씬 `@export`로 주입된다. 사용하거나 제거할지 미결
15. highscore만 런 간 유지, 오그먼트 레지스트리는 비영속
16. **`gameplay.tscn`에 `ext_resource` 다수** — 증강·시설·무기 풀이 씬에 인라인. 카드 추가마다 씬 편집 필요 + `.tscn` 충돌 유발 (`augment-pool-data-driven`)
17. **그룹 기반 런타임 조회** — `get_first_node_in_group`이 11개 파일에서 `gameplay_world`·`augment_progression`·`player`·`weapon_acquisition`을 찾는다. 등록 누락이 조용한 실패가 되고 테스트마다 수동 `add_to_group` 필요
18. **무기 trait `.tres` 이원화** — `resources/weapons/traits/`(무기 코드가 문자열 경로로 로드)와 `resources/player_augments/weapon/trait_*.tres`(오퍼 풀)에 같은 특성이 중복
19. **루트에 게임 코드 13개** — `gameplay.tscn`·오퍼/진행 컨트롤러·레지스트리·`enemy_generator.gd`(짝 씬은 `enemies/`)
20. **테스트 공용 베이스 없음** — 33개 테스트가 `_expect` 헬퍼와 긴 씬 경로(`Layout/Playfield/...`)를 각자 하드코딩. `AGENTS.md` 예시의 `tests/example_test.gd`는 실재하지 않음
21. **`3d/physics_engine="Jolt Physics"`** — 2D 전용 프로젝트에 남은 사문 설정

## 콘텐츠 확장 아이디어

- Threat Tier별 스폰 세트 및 **보스** 콘텐츠
- 플레이어 행동 오그먼트 (대시 등)
- **설정 메뉴** (볼륨 등) — ESC 일시정지는 구현됨, `pause-settings-menu` 카드의 설정 부분은 미완
- 복잡한 무기 trait(도탄·잔류장 등) 플레이 밸런스 튜닝
