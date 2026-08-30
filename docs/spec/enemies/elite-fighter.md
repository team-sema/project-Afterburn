# Elite Fighter

MainEncounterPool과 **분리**된 타임 게이트 적. 일반 Encounter 후보가 아니다.

| 항목 | 값 |
|------|-----|
| Encounter | `threat_elite_single` |
| HP | Threat 2에서 **180**, 이후 Threat마다 **+60** (+ 적 `HEALTH` 증강 배율) |
| 점수 | 40 |
| XP | 확정 드롭 |
| 비주얼 | `enemy_elite_fighter.svg`, 1.35배 · 강화 적색 글로우 |

## 전투

- 이동: 상단 y=72 진입(56px/s) → 좌우 순찰(62px/s). 화면 밖 자동 despawn 정지
- 기본 공격: 1.25초 간격 전방 단발 2회(0.14초 간격), 탄속 165, 첫 지연 0.8초
- 집중 연사: 약 7.5초마다 플레이어 위치 추적 · 0.09초 × 12발, 탄속 190, 첫 연사 지연 4.5초

## 게이트

타이머·Threat 상승·적 증강 오퍼 규칙은 [런·페이싱](#run-pacing) 정본.
