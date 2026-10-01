# 보스

보스는 일반 적·엘리트와 독립된 관문 콘텐츠다. 시퀀스 `BOSS` 스텝에서만 등장하며, `is_boss`로 보스 피해 배율 대상이 된다.

## 구현 상태

- [Wall · 리사이클러](wall.md): 자동 해체구역 3단계 공략(압착 격벽 → 광학 절단기 → 압착 프레스)과 관제 코어 정지 연출을 `labs/bosses/wall/`에서 독립 시험. 메인 시퀀스 `d` 토큰은 이식 전까지 기존 프로토타입(`enemies/boss_wall.tscn`)을 사용.
- [거대 항모 · Boss Lab](carrier.md): 독립 시험 장면. 본 게임 시퀀스·보상에 연결하지 않는다.

## 공통 규칙

- MainEncounterPool에 넣지 않는다. `EncounterSequenceStep.boss_preset`으로만 스폰한다.
- 게이트 흐름(WARNING → 일반 스폰 정지 → 처치 후 탄소거·XP·Threat·적 오퍼)은 엘리트와 같되, HP는 씬 작성값을 유지한다 (엘리트 Threat 공식 미적용).
- `is_elite`와 `is_boss`는 별개다.
- 독립 시험 장면은 보스마다 `labs/bosses/<보스>/`에 두고 Lab 허브에 `보스 · <이름>`으로 등록한다([씬·UI 흐름](../scene-flow.md)).

## 관련 코드

- `threat_elite_controller.gd`, `enemies/boss_wall.tscn`, `resources/encounters/presets/boss_wall.tres`
