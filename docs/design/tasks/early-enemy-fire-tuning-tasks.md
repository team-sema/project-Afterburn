# Tasks — early-enemy-fire-tuning

## Tasks

- [x] Drone (`normal_enemy.tscn`) 사격 오버라이드 완화 (주기 4.5 · 탄속 105 · 첫 사격 1.5)
- [x] Striker (`moving_enemy.tscn`) 사격 오버라이드 완화 (주기 4.5 · 볼리 2 · 탄속 80 · 첫 사격 1.5)
- [x] 현황 스펙 (`docs/spec/enemies.md`)에 초반 사격 압력 표 추가
- [x] 헤드리스 프로브로 씬 반영값 확인 후 프로브 삭제
- [x] 적 관련 smoke 회귀 확인 (편대·연발·자율 사격·Threat 스폰)

## AC

- [x] 씬 인스턴스의 실제 사격 수치가 표와 일치한다
- [x] `EnemyShootComponent` 로직·적 오그먼트 `ACTION_RATE` 경로 변경 없음
- [ ] 사람 플레이 검증: 초반 회피 여유가 충분한지 확인

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-01 | 초안 |
