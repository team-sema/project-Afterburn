# 갭 · 확장 포인트

구현은 됐지만 **미연결·미사용·중복**인 지점. 칸반 백로그 후보와 대응한다.

## 기능 갭

1. **`PlayerAugment.behavior_components`** — 필드만 있고 Applier가 부착하지 않음
2. **`EnemyAugmentGrantComponent`** — API 완비, 씬 사용 0
3. **`EnemyStatModifier.ACTION_RATE`** — `enemy_fire_volume_boost`로 풀 연결됨 (사격 주기 + TimedState)
4. **물리 레이어 3–4** — 이름만, 탄은 layer 0
5. **`WeaponSystem` local multiplier / `_apply_stat_multipliers`** — stub
6. **`clear_augments()`** — 미호출 (씬 리로드에 의존)
7. **무기 교체/해금** — Blaster+Laser 상시
8. **오그먼트 풀** — `world.tscn` 하드코드, 추가 시 씬 편집 필요

## 구조 이슈

9. Enemy `no_health` → `queue_free`와 `DestroyedComponent` **이중 free/이펙트**
10. 카미카제 Hitbox free가 점수/폭발 순서를 건너뛸 수 있음
11. 파일명 typo: `timed_state_componoent.gd`
12. `OnetimeAnimatedEffect` vs `neon_explosion` 이원화
13. `ResourceStash`가 GameStats 홀더 수준으로 얇음
14. highscore만 런 간 유지, 오그먼트 레지스트리는 비영속

## 콘텐츠 확장 아이디어

- 오그먼트 풀 확장 (실드, 플레이어 행동 등)
- 웨이브/보스 대신 점수 구간별 스폰 테이블
- 플레이어 행동 오그먼트 (대시, 실드, 궤도 드론)
- 설정/일시정지 메뉴
