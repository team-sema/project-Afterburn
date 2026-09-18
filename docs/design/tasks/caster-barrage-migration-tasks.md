# 일반 적 탄막 이식

정본: [Caster](../enemies/caster.md), [Striker](../enemies/striker.md), [Interceptor](../enemies/interceptor.md), [전투](../combat.md), [증강](../augments.md).

## 범위와 순서

1. 공통 조준 연발 패턴으로 Striker·Interceptor를 이식한다.
2. Caster 링 패턴을 추가하고 Radial 전용 컴포넌트·분기를 제거한다.
3. Drone을 포함한 일반 조준 패턴에 스폰 시 포화 사격을 연결한다. Caster의 기존 적용 범위를 보존한다.
4. 일정·방향·활성 조건·증강·위협도·수명 회귀와 기존 적 스모크 테스트를 실행한다.

수정 범위: `patterns/`, 관련 `enemies/` 씬·Caster 스크립트, `components/enemy_shoot_component.gd`, 증강·modifier 연결, `tests/`, 관련 기획서와 `docs/barrage-api.md`. 탄막 API 원시 연산·엘리트·특수탄·메인 Encounter 시퀀스는 변경하지 않는다.

## 검증 결과

- 구현 완료: 공통 조준 연발·Caster 링 패턴, 신규 바늘탄 연결, Radial 제거, 스폰 시 명시적 발수 증강 적용.
- 프로젝트 headless editor parse 및 `git diff --check` 통과.
- 스모크 9개 모두 종료 코드 0, PASS/OK: `enemy_pattern_migration`, `interceptor_enemy`, `caster_top_orb_barrage`, `script_pattern`, `base_enemy_projectile`, `enemy_shoot_threshold`, `enemy_augment_policy`, `elite_attack`, `bullet_cancel_reward` (`tests/*_smoke_test.gd`).
- `script_pattern`의 잘못된 상속 거부 오류는 의도된 테스트 출력이다. 별도로 종료 시 ObjectDB/Resource 및 일부 RID 잔존 경고가 있으며 이번 작업에서는 해결하지 않았다.
- 화면을 통한 외형·체감 검증은 미실시. 기존 탄의 초기 확대/섬광은 신규 공통 바늘탄에 포함되지 않는다.
- 메인 Encounter 시퀀스의 게임 규칙은 변경하지 않았다.

## 최종 병합 범위

- 사용자 요청에 따라 같은 브랜치에서 [엘리트·Sniper](elite-sniper-barrage-migration-tasks.md), [Awl 비교](elite-awl-barrage-comparison-tasks.md), [반격탄](counter-shot-barrage-migration-tasks.md)까지 이식을 확장했다.
- 현재까지의 변경을 함께 커밋한다. 메인 Encounter 시퀀스는 에디터 직렬화 결과를 보존한다. 삭제된 명시값은 스크립트 기본값과 동일하고 등장 패턴·대기·관문 규칙은 유지된다. Interceptor 편대 프리셋 변경은 씬 UID 추가뿐이다. 이 직렬화 변경은 별도 게임 기획 변경을 요구하지 않는다.
- 탄 외형/판정 편집 도구는 후속 작업이며 이번 병합에 포함하지 않는다.
