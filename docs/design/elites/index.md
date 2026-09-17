# 엘리트

엘리트는 일반 적과 독립된 콘텐츠다. 일반 적과 외형 계통이나 코드 베이스를 공유해도 의도·공격·수치·보상·완료 조건은 반드시 별도 문서로 관리한다.

## 구현 상태

- [Elite Fighter](elite-fighter.md): 구현·메인 ELITE 관문 연결.
- [Elite Awl](elite-awl.md): 구현·메인 ELITE 관문 연결.
- [Elite Bomb](elite-bomb.md): 외형 시안만 존재. 전투·스폰 미구현.
- [Elite Caster](elite-caster.md): 외형 시안만 존재. 전투·스폰 미구현.

## 공통 규칙

- 일반 MainEncounterPool에는 등록하지 않는다. ELITE 스텝에서 ThreatEliteController가 전용 Encounter를 생성한다. Director 미사용 시에만 60초 타이머 경로를 쓴다.
- 관문이 요청하는 다음 Threat 기준으로 짝수는 Fighter, 홀수는 Awl이다. 현재 Threat는 처치 정산 완료 뒤 상승한다.
- 기본 HP = 420 + max(0, 관문 Threat - 2) × 140. 스폰 시 HEALTH 증강을 곱하고 반올림한다. 씬만 직접 실행했을 때의 HP와 구분한다.
- is_elite와 is_boss는 별개다. 현재 두 엘리트는 보스 피해 배율 대상이 아니다.
- 처치·탄소거·XP 정산·적 오퍼·일반 스폰 재개의 순서는 [런 페이싱](../run-pacing.md)을 따른다.
- 베이스 Enemy 컴포넌트는 [일반 적](../enemies/index.md)의 공통 구현을 공유한다. 콘텐츠 문서의 분류와 코드 상속은 별개다.

## 관련 코드·검증

- threat_elite_controller.gd, enemies/elite_fighter.tscn, enemies/elite_awl.tscn
- tests/threat_elite_progression_smoke_test.gd, tests/elite_attack_smoke_test.gd, tests/elite_charge_smoke_test.gd
