# Threat Monitor Tasks

정본: [전투](../combat.md) · [씬 플로우](../scene-flow.md) · [런·페이싱](../run-pacing.md) · [개요](../overview.md)

## 작업

- [x] 실시간 위협도 구성 값과 종합 공식 문서화
- [x] 감시 범위 안의 적·적탄을 주기적으로 읽는 `ThreatMonitor` 구현
- [x] F6 전용 플레이 장면과 실시간 HUD·최근 그래프 구현
- [x] 장면 연결, 계산식, 감시 범위, 재시작 동작 스모크 테스트
- [x] 플레이어 위치와 무관한 고유 위협도 계산 검증
- [x] Awl 등 접촉 피해 몸체의 현재 영역과 예상 이동 경로 반영
- [x] 방어 구역의 정지 안전 비율과 안전 공간 분절을 탄막 패턴 복잡도에 반영
- [x] 적 HP는 직접 점수가 아닌 위협 지속 보정값으로 제한
- [x] Sniper 조준 진행률과 전용 고속탄 이동 경로 반영
- [x] 동시 공격원 수와 공격 종류 다양성에 상한이 있는 혼합 편성 보정 적용
- [x] Godot 에디터 파싱과 관련 회귀 테스트 실행

## 예상 수정 경로

- `docs/design/combat.md`
- `docs/design/overview.md`
- `docs/design/run-pacing.md`
- `docs/design/scene-flow.md`
- `docs/design/tasks/README.md`
- `threat_monitor/`
- `components/` · `enemies/` · `projectiles/`의 적별 계측 인터페이스
- `resources/encounter_sequences/waves/drone_swarm_wave.tres` (Godot 4.7에서 읽을 수 있는 동일 데이터 표기)
- `tests/threat_monitor_smoke_test.gd` · 관련 적 회귀 테스트

## 검증 명령

```powershell
.\tools\run-godot.cmd --headless --script res://tests/threat_monitor_smoke_test.gd
.\tools\run-godot.cmd --headless --editor --quit
```

## 검증 결과

- `threat_monitor_smoke_test`: PASS
- 전용 장면 120프레임 실행: 종료 코드 0
- `encounter_sequence`, `enemy_shoot_burst`, `caster_top_orb_barrage`, `sniper_enemy`, `bomb_proximity_fuse`, `kamikaze_aim_charge`, `interceptor_enemy`, `elite_attack`, `elite_charge`: PASS
- Godot 4.7 에디터 파싱: 종료 코드 0
- 일부 기존 테스트는 종료 시 ObjectDB/resource 잔존 경고를 출력하지만 명시적 PASS와 종료 코드 0을 확인했다.
