# 갭 · 확장 포인트

구현은 됐지만 **미연결·미사용·중복**인 지점. 칸반 백로그 후보와 대응한다.

## 기능 갭

1. **`PlayerAugment.behavior_components`** — 필드만 있고 Applier가 부착하지 않음
2. **`EnemyAugmentGrantComponent`** — API 완비, 씬 사용 0
3. **`EnemyStatModifier.ACTION_RATE`** — `enemy_fire_volume_boost`로 풀 연결됨 (사격 주기 + TimedState)
4. **물리 레이어 3–4** — 이름만, 탄은 layer 0
5. **`WeaponSystem` local multiplier / `_apply_stat_multipliers`** — stub
6. **`clear_augments()`** — 미호출 (씬 리로드에 의존)
7. **무기 슬롯** — 메인/예비·샷건·픽업은 있음. 해금 트리·확인 UI 등은 카드 백로그
8. **오그먼트 풀** — `gameplay.tscn` 하드코드, 추가 시 씬 편집 필요. 가중치 없이 균등 셔플이라 후보가 11장으로 늘며 카드별 등장 확률이 낮아짐
9. **부위 모듈 밸런스 수치** — `module_count_values`는 전부 플레이스홀더. 기본 최대 선체가 1이라 선체·실드 가산도 1 단위로 잡혀 있음
10. **궤도 방벽 + 격납고** — 탄약 카운터가 없어(`get_consumable_max()` = -1) 격납고 보너스를 받지 않음. 환산 규칙 미정
11. **실드 리필 수단** — `ShieldComponent.restore_shield()`를 부르는 곳이 없음. 충전 조건 미정
12. **우측 패널 세로 여유** — 항목 추가 전 `ship_facility_upgrade_test`의 동적 fit 검사를 먼저 확인

## 구조 이슈

11. Enemy `no_health` → `queue_free`와 `DestroyedComponent` **이중 free/이펙트**
12. 카미카제 Hitbox free가 점수/폭발 순서를 건너뛸 수 있음
13. 파일명 typo: `timed_state_componoent.gd`
14. `OnetimeAnimatedEffect` vs `neon_explosion` 이원화
15. `ResourceStash`가 GameStats 홀더 수준으로 얇음
16. highscore만 런 간 유지, 오그먼트 레지스트리는 비영속

## 콘텐츠 확장 아이디어

- 오그먼트 풀 확장 (실드, 플레이어 행동 등)
- Threat Tier별 스폰 세트 및 보스 콘텐츠 확장
- 플레이어 행동 오그먼트 (대시, 실드, 궤도 드론)
- **설정 메뉴** (볼륨 등) — ESC 일시정지는 구현됨, `pause-settings-menu` 카드의 설정 부분은 미완
