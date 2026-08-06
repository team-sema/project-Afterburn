# Feature: 폭탄 근접 자폭

## 목적

느리게 하강하는 고체력 폭탄 적을 추가해, 플레이어가 접근하면 경고(적색 점멸) 후 넓은 범위로 자폭하게 한다.

## 동작 조건

1. `bomb_enemy.tscn` — HP 140, 점수 20, 속도 `(0, 16)`, 투사체 없음
2. `BombProximityFuseComponent`: 플레이어가 `trigger_radius`(60) 안이면 정지 → `arm_duration`(2s) 동안 적색 점멸 `flash_count`(3)회와 범위 프리뷰 → 자폭
3. 폭발 VFX 최대 링 · AOE · 반투명 프리뷰 반경 = `base_explosion_radius(40) * blast_size_multiplier(1.5) = 60px`
4. `EnemyGenerator`가 Bomb 타이머로 단발 스폰
5. 비주얼: `assets/svg/enemy_bomb.svg`

## Acceptance Criteria

- [x] Bomb 타입이 생성기에서 스폰된다
- [x] 근접 시 정지 후 ~2초 3회 적색 점멸 뒤 자폭한다
- [x] 자폭 범위/연출이 기존 폭발의 약 1.5배이다
- [x] 판정·VFX 최대 링·범위 프리뷰 radius가 일치한다
- [x] 투사체를 쏘지 않는다
- [x] `docs/spec/enemies.md` · `components.md`에 반영된다
- [x] 스모크 테스트 `tests/bomb_proximity_fuse_smoke_test.gd`

## 구현 메모

- 기본 `DestroyedComponent` VFX는 자폭 시 끊고 컴포넌트가 확대 폭발을 스폰한다

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-31 | 초기: Bomb 근접 신관·1.5× 자폭 |
| 2026-08-06 | 판정·VFX 60px 통일 · 반투명 범위 프리뷰 · 고속 기폭 증강 연동 |
