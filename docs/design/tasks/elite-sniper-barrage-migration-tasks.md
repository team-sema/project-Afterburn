# 엘리트·저격수 탄막 연결 및 Legacy 정리

정본: [Elite Awl](../enemies/elite-awl.md), [Elite Fighter](../enemies/elite-fighter.md), [Sniper](../enemies/sniper.md), [탄막 API](../../barrage-api.md).

## 완료 작업

- 화면 비교에서 채택한 Awl 신규 불꽃탄을 유지하고 Legacy 씬·탄 구현·비교 캡처 스크립트를 제거했다.
- Elite Fighter 사격을 유한 Sequence로 연결했다. 이동·고정 조준 예고·회복은 공격 제어자가 소유한다.
- Sniper 전용 탄은 BarrageShot 어댑터로 연결했다. 피격 흔들림이 반동을 덮어쓰던 문제를 지속 오프셋 합산으로 수정했다.
- Lab 허브에서 세 기체를 선택하고 재생하도록 갱신했다.
- 현재 Interceptor 씬의 사용자 조정값을 보존하고 문서·테스트 기대값을 맞췄다. main_encounter_sequence와 편대 프리셋은 수정하지 않았다.

## 검증

- 스모크 PASS/OK, 종료 0: elite_awl_barrage, elite_charge, elite_charge_visual, elite_attack, sniper_enemy, sniper_barrage_shot, enemy_pattern_migration, interceptor_enemy, threat_elite_progression.
- Sniper 어댑터는 설정 스냅샷 독립성, 변환된 월드 아래 발사 좌표·방향, 고속 판정·피해량, 사거리 종료·중복 종료 방지를 검증했다.
- 에디터 검사 종료 0, 누락 의존성·스크립트 파싱 오류 없음. 삭제된 Legacy/Radial 경로의 실행 코드 참조 없음.
- 실제 D3D12 Lab 렌더링을 artifacts/capture_enemy_attacks.gd로 확인했다. 세 기체의 캡처는 artifacts/enemy_attack_*.png에 남겼다.
- 종료 시 ObjectDB/Resource/RID 잔존 메시지가 남는다. 그래픽 실행에는 샌드박스의 사용자 셰이더 캐시·인증서 저장소 접근 오류도 있으나 캡처와 실행은 성공했다. 위 테스트 실패와 구분한다.
- git diff --check 통과. 커밋·병합은 수행하지 않았다.
