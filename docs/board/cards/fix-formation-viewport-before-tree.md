# 편대 스폰 viewport 초기화 순서

## 목표

- `EnemySpawner`가 의존성·spawn ID만 트리 진입 전에 주입
- `FormationController`가 트리에 들어가 Layout을 준비한 뒤 viewport 기준 spawn anchor와 슬롯 위치를 적용

## AC

- Drone/Awl Encounter 스폰 시 `!is_inside_tree()` / viewport 접근 에러 없음
- 편대 중앙의 대각·ping-pong 이동과 슬롯 간격은 기존과 동일
