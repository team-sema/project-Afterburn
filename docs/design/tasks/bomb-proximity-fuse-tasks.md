# Tasks: bomb-proximity-fuse

## Task 1 — 아트·씬

- 목적: Bomb 적 엔티티
- 수정 예상: `assets/svg/enemy_bomb.svg`, `enemies/bomb_enemy.*`
- 완료: 씬이 HP/점수/속도 스펙과 일치

## Task 2 — 근접 신관 컴포넌트

- 목적: 트리거 → 점멸 → 1.5× 자폭
- 수정 예상: `components/bomb_proximity_fuse_component.*`
- 완료: AC 점멸·반경 충족

## Task 3 — 생성기·스펙·테스트

- 목적: 스폰 + 문서 + 스모크
- 수정 예상: `enemy_generator.gd`, `enemies/enemy_generator.tscn`, `docs/spec/*`, `tests/bomb_proximity_fuse_smoke_test.gd`
- 완료: 생성·스펙·테스트 준비

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-31 | 초기 Task |
