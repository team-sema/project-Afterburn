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
9. **WEAPON_TRAIT 랭크 스케일** — rank≥1 온/오프. 랭크별 수치 증가는 없음
10. **우측 패널 세로 여유** — 항목 추가 전 동적 fit 검사를 먼저 확인

## 구조 이슈

11. Enemy `no_health` → `queue_free`와 `DestroyedComponent` **이중 free/이펙트**
12. 카미카제 Hitbox free가 점수/폭발 순서를 건너뛸 수 있음
13. 파일명 typo: `timed_state_componoent.gd`
14. `OnetimeAnimatedEffect` vs `neon_explosion` 이원화
15. `ResourceStash`가 GameStats 홀더 수준으로 얇음
16. highscore만 런 간 유지, 오그먼트 레지스트리는 비영속

## 콘텐츠 확장 아이디어

- Threat Tier별 스폰 세트 및 **보스** 콘텐츠
- 플레이어 행동 오그먼트 (대시 등)
- **설정 메뉴** (볼륨 등) — ESC 일시정지는 구현됨, `pause-settings-menu` 카드의 설정 부분은 미완
- 복잡한 무기 trait(도탄·잔류장 등) 플레이 밸런스 튜닝
