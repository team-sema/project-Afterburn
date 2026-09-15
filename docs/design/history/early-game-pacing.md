# Feature: 초반 페이싱 조정

> 과거 기능 작업의 설계·결정 이력입니다. 아래 수치·상태·문서 운영 지침은 당시 기록이며 현재 구현 기준이 아닙니다. 현재 기준은 [통합 기획서](../README.md)를 따릅니다. 미구현 제안은 별도 확정 없이 구현하지 않습니다.

## 목적

Threat 1~2 초반 Encounter 빈도·로스터·적 HP·Bomb 편대·XP 드롭을 조정해 무기 선택 직후 난이도 스파이크를 완화한다.

## 동작 조건

- 일반 Encounter 간격 **2.8s ± 0.3s**
- Threat 1: `striker_drone_diamond_13`, `bomb_drone_diamond`, `interceptor_pair` 포함
- HP: Drone 28, Striker 60, Awl 80, Bomb 160, Interceptor 50
- Bomb 편대: 상단 Bomb, 130px/s 돌진, 3초 퓨즈
- XP drop_chance **0.45**
- 활성 Tanker 있을 때 `tanker_guard_sniper` → `sniper_reinforcement`

## Acceptance Criteria

- [x] `docs/design/enemies.md`·`augments.md`·`components.md`가 코드와 일치
- [x] `enemy_threat_spawn_smoke_test.gd`가 새 페이싱·HP·Bomb·Tanker 대체 검증
- [x] `sniper_single.tres`(`sniper_reinforcement`) 추가

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-29 | 초안 |
