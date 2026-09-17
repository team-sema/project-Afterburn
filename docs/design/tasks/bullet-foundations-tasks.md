# 탄환 기본 종류 확장

정본: [전투 — 탄환 기본 종류 확장](../combat.md#탄환-기본-종류-확장)

## 범위·순서

- [x] 외형/이동 Resource와 공통 적탄 구현 (`projectiles/`, `resources/projectiles/`).
- [x] 미래 경로·판정 크기를 위협도 계측에 연결 (`threat_monitor/threat_monitor.gd`).
- [x] 비교·회피·판정·일시정지·재발사·소거 시험 장면 구현 (`projectiles/bullet_lab.*`).
- [x] 궤적·격리·피격·수명·소거·계측·UI 검증 (`tests/`).
- [x] 기획서의 구현 상태와 검증 결과 갱신.

## 검증 기록

- 2026-09-16: 프로젝트 파싱 검사 종료 코드 0.
- 신규 `bullet_foundations_smoke_test.gd` PASS. 실제 렌더링 모드에서도 PASS, [화면](../../../artifacts/bullet_lab.png) 확인.
- `base_enemy_projectile`, `bullet_cancel_reward`, `threat_monitor`, `enemy_shoot_burst`, `enemy_shoot_threshold`, `enemy_shoot_autonomous_scene` 스모크 테스트 PASS. `sniper_enemy_smoke_test` OK. 모두 종료 코드 0.
- 안전선 테스트가 이미 삭제된 `EliteBarrageShootComponent`를 참조해 중단되는 문제를 현재 남아 있는 사격 컴포넌트 검사로 수정한 뒤 통과.
- Headless 실행에 기존 UID/리소스 잔존 경고, OpenGL 실행에 인증서 저장소 읽기 오류가 동반됐다. 렌더링 실행에서는 종료 리소스 경고 없이 PASS.
- 선회·가감속, 실제 적 배정, Encounter 밸런스 평가는 후속 작업이다.

## 곡선 레이저 시험 추가 · 2026-09-16

- [x] 곡선 레이저의 연속 몸통·지속 피격 판정 구현 (`projectiles/curved_laser*`).
- [x] 전용 진입 씬과 기존 비교 UI에 꽃잎/단발/좌우 선회 선택 연결.
- [x] 몸통 피격·무적·수명·화면 이탈·소거·예측을 신규 스모크 테스트로 검증.
- [x] 기존 기본탄 비교 테스트 PASS, 탄소거 XP 테스트에 레이저를 추가해 PASS.
- [x] 프로젝트 파싱 검사 통과. 실제 그래픽 실행에서 [꽃잎 화면](../../../artifacts/curved_laser_lab.png)을 확인.
- UID·인증서 저장소·종료 리소스 메시지는 기존 환경 경고로 남음. 현재 수치와 완료 조건의 정본은 전투 문서의 곡선 레이저 절.

## 탄환 렌더링 최적화 · 2026-09-16

- [x] 새 일반 탄의 MultiMesh, 레이저 리본 통합 메시, 원/캡슐 판정 표시 인스턴싱 구현.
- [x] 캡슐 반지름과 폭 프로필의 반복 계산 제거. 36구간 충돌과 기존 피격·소거 계약 유지.
- [x] 시험 장면의 엔진/자체 판정 표시 중복 제거. 기체 코어 표시도 공유 렌더러로 전달.
- [x] 배치 격리, 혼합 탄종 순서, 숨김, 삭제, 일시정지 회귀 테스트 추가. Headless 및 실제 OpenGL 모드 PASS.
- [x] foundation / curved laser / bullet cancel reward / threat monitor 회귀 PASS, 종료 코드 0. 레이저는 프로젝트 기본 D3D12 Mobile 렌더러에서도 PASS.
- [x] 실제 화면으로 일반 탄/레이저/판정 표시 전후 확인. 원탄 가장자리의 평활화 방식은 달라져 픽셀 단위 동일 이미지는 아니다.

### 측정 결과

- 환경: 래퍼가 실제 실행한 Godot 4.7, GTX 1660 Ti, OpenGL Compatibility, VSync OFF, FPS 제한 해제. 각 조건 90프레임 중 첫 30프레임 제외한 중앙값. 프레임 간격은 OS/표시 대기를 포함하며 GPU 시간이나 전체 게임 성능 보장이 아니다.
- 기존 시험 장면 진단 대비 레이저 12줄: 표시 OFF 104→69 draw calls, 표시 ON 1,806→70, 프레임 간격 약 42.1→8.3ms. 이후 시험 기체 판정도 동일 디버그 배치에 포함했다.
- 별도 UI 없는 재현 벤치마크는 현재 시뮬레이션을 공유하고 `use_batched_rendering`만 비교한다. 레이저 12줄: OFF 36→1 draw call, ON 900→2; ON 22.17→8.37ms. 이 비교의 기존 경로는 자체 판정 표시만 사용하므로 과거 중복 표시 수치와 구분한다.
- 원탄 1,000발: OFF 6,000→1 draw call, 25.25→8.45ms. ON 8,000→2, 32.13→12.15ms.
- 쌀탄 1,000발: OFF 3,000→1 draw call, 15.16→8.40ms. ON 5,000→2, 21.62→11.50ms.
- 배치 데이터 준비/업로드 CPU 중앙값: 원탄 OFF 2.86ms / ON 6.80ms, 쌀탄 OFF 2.19ms / ON 6.61ms, 레이저 OFF 1.61ms / ON 2.82ms. 캡슐의 물리 갱신 비용과 개별 노드 처리 비용은 남아 있다. 충돌/풀링까지 재설계한 결과로 해석하지 않는다.
- 원자료: [JSON](../../../artifacts/projectile_render_benchmark.json). 재실행: `tools/run-godot.cmd --rendering-method gl_compatibility --script res://tests/projectile_render_benchmark.gd`; `-- --capture`를 붙이면 같은 시각의 전후 PNG도 저장한다.
- 실행 환경의 기존 UID, 인증서 저장소, shader cache 쓰기, 종료 시 리소스 잔존 메시지는 PASS 결과와 별도로 남아 있다.
