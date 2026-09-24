# 거대 항모 Boss Lab

## 기획 기준

- [거대 항모 · Boss Lab](../bosses/carrier.md)
- [씬·UI 흐름](../scene-flow.md)
- [이펙트](../effects.md)

## 작업 범위와 결과

1. 독립 Boss Lab과 허브 진입을 추가했다. 본 게임 런·보상 연결은 범위 밖이다.
2. 선체에 장착된 회전 포대, 독립 격납고·호위포, 함재기 편대와 구역별 탄막을 구현했다.
3. 상단 통합 HP, 공용 네온 폭발, 격침 줌아웃·침강과 연출 중 재시작·일시정지를 연결했다.
4. `labs/carrier_*`, `patterns/carrier_lab_pattern.gd`, `assets/svg/carrier_*`, 전용 스모크 테스트와 관련 기획서·탐색 링크를 변경했다.

## 검증

- 2026-09-25: `tools/run-godot.cmd --headless --script res://tests/carrier_boss_lab_smoke_test.gd` — PASS, 종료 코드 0.
- 실제 블래스터 피격, 부위별 피해·구역 전환, 포신 선회·발사 방향, 편대 출격과 취소, 격침·카메라·배경·HP바, 일시정지·연출 중 재시작을 검증했다.
- 실제 렌더링에서 부품의 선체 동반 진입, 회전·출격, 공용 폭발과 격침 연출을 확인했다.
- `git diff --check` 통과. Godot 종료 시 ObjectDB/리소스 정리 경고는 별도로 남아 있다.
