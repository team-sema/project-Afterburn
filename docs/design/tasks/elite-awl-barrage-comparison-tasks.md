# Elite Awl 신규 불꽃탄 비교

정본: [Elite Awl](../enemies/elite-awl.md#탄막-이식), [전투](../combat.md).

## 작업

- 기존 Elite Awl 씬을 `enemies/elite_awl_legacy.tscn`으로 보존. 신규 씬은 기존 단발 어댑터로 FoundationBullet을 사용.
- SVG 외형과 기존 BulletTrailEffect로 불꽃을 근사. 이동·예고·장식 불씨는 공유.
- 공격용 RNG를 장식 RNG와 분리하고 비교 시 고정 시드 사용.
- Lab 허브에서 신규/Legacy 전환·다시 재생 제공. 발사 일정 Sequence 이관은 이번 범위가 아님.

## 검증

- 불씨 삼각분할 오류 수정: 소멸 직전 폭이 화면 좌표 반올림으로 소실되는 경우를 재현했다. 중심 기준 도형과 별도 draw transform, 미세 폭 그리기 생략으로 수정. `elite_charge_visual_smoke_test.gd` PASS(기존 실패 44건 재현·수정 도형 360건 통과), 기존 `elite_charge_smoke_test.gd` PASS. D3D12 비교 Lab 900프레임 실행에서 triangulation 오류 없음·종료 0. 기존 종료 리소스 경고는 남음.

- `elite_awl_barrage_smoke_test.gd`: PASS, 종료 0. 중첩 탄수/속도 조건에서 양쪽 발수·속도·방향·경로 생성 위치 비교, 신규 판정·수명·꼬리, Lab 전환 확인.
- `elite_charge_smoke_test.gd`: PASS, 종료 0. 기존 조준·고정·돌진·재진입·이동 증강 확인.
- `artifacts/capture_elite_awl_comparison.gd`: 실제 D3D12 렌더링 두 버전 캡처 성공. `elite_awl_new_compare.png`, `elite_awl_legacy_compare.png` 확인. 신규 쪽은 밝은 중심과 부드러운 가장자리로 다각형 원본과 차이가 남는다.
- `git diff --check` 통과. 종료 ObjectDB/Resource 잔존 경고는 남음. Editor 검사 중 이전 Radial 스크립트를 다시 열려는 오류가 있었으며 이 작업 시작 전에 다시 생긴 Radial 씬·메인 시퀀스 변경은 수정하지 않음.
- 실시간 캡처는 같은 고정 프레임을 보장하지 않는다. 발사 난수 동등성은 위 스모크 테스트로 검증한다.
- 후속 정리: 다시 남아 있던 `radial_barrage_shoot_component.tscn`이 삭제된 스크립트를 참조해 missing dependencies를 발생시켰다. 잔여 씬 및 로컬 최근 씬 항목을 제거했다. 재검사에서 해당 의존성 오류 없음·종료 0. 별도의 인증서 저장소/사용자 editor settings 접근 오류와 종료 리소스 경고는 남았다.

## 채택 후 정리

- 사용자 화면 확인 후 신규 외형 채택. Legacy 씬·다각형 탄·비교 캡처 스크립트 제거. 위 항목은 비교 당시 기록이다.
- Lab은 enemy_attack_lab으로 변경하고 Elite Fighter·Sniper 재생을 추가했다.

