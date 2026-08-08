# Sniper Enemy Tasks

## AC

- [x] ENTRY→POSITIONING 후 상단 원거리 포지션 유지 (재포지션 없음)
- [x] AIMING 4초 동안 플레이어 지속 추적 + 옅은 이중선 ease-out 수렴 + 0.18초 완전 조준
- [x] 발사 순간 방향 확정, 900px/s 고속탄은 예고 경로로 월드 고정 이동
- [x] 발사 시 기체 비주얼이 반대 방향으로 반동한 뒤 원위치 복귀
- [x] COOLDOWN 2.5초 후 AIMING 재진입, 최소 3회 연속 발사 안정
- [x] `tanker_guard_sniper` Threat 풀 등록 · 현황 스펙·스모크 테스트

## Tasks

1. [x] Hold step · entry sequence · sniper scene
2. [x] Dual-line aim telegraph + sniper bullet + attack component
3. [x] Encounter pool · modifier ACTION_RATE · docs · smoke test

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-09 | Cone·레이저를 이중 조준선·고속탄으로 교체하고 완전 조준·반동 추가 |
| 2026-08-08 | 구현 완료 · AC 체크 |
| 2026-08-08 | 초안 |
