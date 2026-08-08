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
- 단일 적은 기존 `EnemySpawnPattern`, Drone/Awl 편대는 `EncounterPreset`으로 구성하고 공용 `EnemySpawner`가 두 경로를 생성한다.
- 2026-08-01 `feature/enemy-threat-tier-spawning` → main (검증 대기)

## 후속 통합

- 2026-08-08 최소 Threat + 균등 `EnemySpawnSet` 구조를 `MainEncounterPool`의 Threat별 weight로 대체했다.
- 단일 적을 포함한 모든 라이브 스폰을 `EncounterPreset → EnemySpawner → FormationController` 경로로 통일하고 중첩 pool을 평탄화했다.
