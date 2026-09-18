# 반격탄 API 이식

정본: [오그먼트](../augments.md), [탄막 API](../../barrage-api.md).

## 작업

- CounterShotComponent의 PackedScene 생성을 BarrageShot/BarrageVolley로 교체했다.
- 원형 반격탄과 공통 입자 꼬리, 발사 방향 기준 파동을 counter_wave_shot에 구성했다.
- 피격/사망 트리거·쿨다운·조준·다발 설정을 유지하고 사망 후 발사와 월드 삭제 취소를 분리했다.
- Sniper 어댑터와 일반 오퍼 풀 제외를 유지했다. curve_projectile은 실행 중 반격 경로에서 분리되었으나 기존 회귀 테스트가 참조하므로 파일 삭제는 별도 레거시 정리에 남긴다.

## 검증

- counter_shot_barrage_smoke_test: PASS. 피격 중복 쿨다운, 발수·각도·탄속·좌표 스냅샷, 원형 판정, 방향 기준 파동, 사망 직후 생성, 월드 제거 시 취소, 타깃 없음·겹침을 확인한다.
- weapon_test_lab_smoke_test, augment_pool_data_driven_smoke_test: PASS, 종료 0. Lab 반격 카드 연결 및 오퍼 풀 제외 유지.
- 종료 ObjectDB/Resource/RID 잔존 메시지는 테스트 실패와 별도로 남아 있다.
