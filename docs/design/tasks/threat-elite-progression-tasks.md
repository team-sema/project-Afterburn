# threat-elite-progression tasks

- [x] 60초 엘리트 소환과 처치 시 Threat 상승·ENEMY 오퍼 연결
- [x] `threat_elite_single` + EliteFighter 상단 순찰·전방 2연사·플레이어 추적 집중 연사
- [x] 엘리트 전투/오퍼 중 일반 Encounter와 Threat 타이머 정지
- [x] 엘리트 처치 후 ENEMY 오퍼 요청, 선택 완료 후 진행 재개
- [x] HUD `ELITE ENGAGED` 상태
- [x] 현황 스펙·시스템 설계·칸반 동기화
- [x] 전용 루프 및 기존 진행/Threat 스폰 회귀 테스트

## AC 검증

1. 60초마다 다음 Threat의 엘리트 1기만 등장하고, 처치해야 Threat가 상승한다.
2. 엘리트 처치 전 `pending_offers`와 ENEMY 오퍼는 비어 있다.
3. 처치 뒤 ENEMY 오퍼가 열리고 선택한 증강이 레지스트리에 적용된다.
4. 오퍼 완료 뒤 일반 스폰과 다음 60초 타이머가 재개된다.
5. 다음 엘리트 HP는 Threat 증가분과 기존 적 HEALTH 증강을 함께 반영한다.
