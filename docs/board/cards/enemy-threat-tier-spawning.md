# Threat Tier 기반 적 스폰

## 목표

- 적 스폰 단위마다 최소 Threat Tier를 데이터로 지정한다.
- 현재 Threat 이하의 스폰 단위만 후보로 선별한다.
- Drone/Awl 편대와 단일 적 스폰 동작을 유지한다.
- 점수 조건 대신 시간 기반 Threat를 적 등장 progression의 기준으로 사용한다.

## 완료 조건

- Tier 1에서 기본 적만, Threat 상승 후 상위 Tier 적이 후보에 포함된다.
- EnemyGenerator가 AugmentProgressionController의 현재 Threat를 사용한다.
- 스폰 선별 스모크 테스트와 프로젝트 파싱이 통과한다.

## 구현

- `EnemySpawnSet` 리소스와 Threat 기반 균등 후보 선택을 추가했다.
- Tier 1: Drone/Striker, Tier 2: Awl/Bomb, Tier 3: Caster로 구성했다.
- 편대별 생성·튜닝을 `EnemySpawnPattern` Resource로 분리해 Generator의 Formation별 분기를 제거했다.
- 2026-08-01 `feature/enemy-threat-tier-spawning` → main (검증 대기)
