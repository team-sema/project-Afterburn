# 탄막 작성 API

## 표현력 확장 검토 수정 — 2026-09-17

정본: [전투](../combat.md), 사용 계약: [API 레퍼런스](../../barrage-api.md).

- [x] Easing 보간 범위 제한 및 최대 히트박스 배율 계산의 전제 갱신.
- [x] 단일 heading_wave 최적화에 반복 종료 각도 누적·유한 반복 종료 방향 반영. 기간 0인 유한 파동은 일반 평가 경로 사용.
- [x] `bullet_behavior_smoke_test`에 모든 Tween 전환/ease 조합의 속성 범위·위협 반경 검사, 파동 위상·기간·유한/무한 반복의 위치/속도 동등성 회귀 추가.
- 검증: Behavior, 캐시(1477개 시각), 호밍, Barrage API smoke test 모두 PASS/종료 코드 0. 기존 종료 ObjectDB/리소스 잔존 경고는 별도.

## 표현력 확장 1차 — 2026-09-17

정본: [전투 — 발사 일정·Behavior 표현력 확장](../combat.md#발사-일정behavior-표현력-확장--구현-완료). 사용법: [API 레퍼런스](../../barrage-api.md).

- [x] `BarrageSequence.build(params)` 훅, `EnemyShootComponent.pattern_params`, Lab 로더의 빈 Dictionary 전달.
- [x] `rotate_to`, `aim()` 단계(`BarrageStep.Action` 끝에 추가), `BarrageVolley.aim` 열거값(NONE/EACH_SHOT/LOCKED)과 `aimed` 호환 별칭, `relative_to_emitter`. Player의 잠금 상태·LOCKED 건너뛰기·발사자 회전 적용.
- [x] `BulletAction.transition_type/ease_type`, `progress()`, `eased()` 빌더(Behavior는 마지막 Action, Action은 자기 자신). `_apply`와 `_forward_velocity` 빠른 경로 모두 같은 weight 사용.
- [x] `heading_wave` 중심을 Action 시작 heading으로 변경. 런타임·빠른 경로·기준 해석기 fixture 동시 갱신.
- [x] SPAWN 자리 확정은 정본에 설계만 기록. jitter는 사용자 결정으로 제외.
- [x] Drone 패턴은 `volley.aim = Aim.EACH_SHOT`으로 표기만 바꿈(동작 동일).
- 검증: `barrage_api_smoke_test`(rotate_to 반복 초기화, aim()/LOCKED/EACH_SHOT 혼합·표적 이동, 잠금 없는 LOCKED 건너뛰기, 고정 표적 모드 거부, relative_to_emitter, aimed 매핑), `bullet_behavior_smoke_test`(선회 뒤 파동 중심, ease-in 곡선·적분 거리 60/45px, 병렬 자식 easing, turn_at 무시), `script_pattern_smoke_test`(build 전 빈 패턴 거부, 기본값, pattern_params 전달, 위협 요약) PASS.
- 회귀: behavior_cache(기준 해석기 동등성)·homing_bullet·pattern_lab·bullet_foundations·textured_bullet·enemy_barrage_shot·projectile_batch·curved_laser·bullet_cancel_reward PASS. 프로젝트 파싱 종료 코드 0.
- `projectile_trail_smoke_test`는 `diamond_trail.tres`(lifetime 0.5, 조정값 유지) 대신 lifetime 0.22의 명시적 fixture를 쓰도록 고쳐 PASS. 이후 `tests/*_test.gd` 전체 실행에서 실패한 5종(augment_resume_burst, enemy_near_death_experience, godot_editor_updates, side_hud_crisp_rendering, weapon_system_tuning)은 `main` worktree에서도 같은 메시지로 실패하여 이 브랜치와 무관한 기존 실패다.
- 예제 패턴 추가: `patterns/locked_burst_pattern.gd`(aim()+LOCKED 3연발), `patterns/aimed_fan_burst_pattern.gd`(5방향 부채꼴 EACH_SHOT 5연발). 본 게임 배정 없음. 에디터 재저장으로 주석이 지워진 `main_encounter_sequence.tres`는 커밋 전 복원했다.

## snapshot 텍스처 복제 수정 — 2026-09-17

- 정본: [전투](../combat.md). 사용 계약: [API 레퍼런스](../../barrage-api.md#player--sequence-추가-api).
- 원인: `BarrageSequence.snapshot()`의 `DEEP_DUPLICATE_ALL`이 needle/diamond_trail 프리셋의 `CompressedTexture2D`까지 복제했다. `BulletAppearance.render_key()`와 `ProjectileTrailManager`는 텍스처 RID로 묶음을 나누므로 `play()`마다(적 스폰마다) 새 RID가 생겨 발사자별로 MultiMesh가 갈라지고 텍스처가 재업로드됐다. Drone 패턴을 두 번 snapshot해 RID 불일치를 headless로 확인했다.
- 수정: 설정 Resource(Step·Volley·Shot·Appearance·Behavior·Action·TrailEffect)만 재귀 복사하고 그 외 Resource(텍스처 등)는 공유하는 `clone_settings()`로 교체. 프리셋 격리 계약은 유지한다.
- `barrage_api_smoke_test.gd`에 회귀 추가: 두 snapshot의 텍스처 동일·render_key 동일·실제 생성 탄의 `_render_key` 동일, 프리셋 후속 편집 격리. PASS.
- 회귀: script_pattern·bullet_behavior·bullet_foundations·textured_bullet·homing_bullet·enemy_barrage_shot·projectile_batch·behavior_cache·curved_laser·bullet_cancel_reward PASS.
- 별도 발견: `projectile_trail_smoke_test.gd`는 이번 변경과 무관하게 실패한다. `diamond_trail.tres`의 lifetime이 0.5로 편집돼 테스트의 0.22초 가정(0.3초 뒤 소멸)과 어긋난다. 이전 wave 프리셋 사례처럼 테스트가 프리셋 대신 명시적 fixture를 쓰도록 고쳐야 한다. 미수정.
- 시도 후 되돌림: `FoundationBullet`의 탄별 `behavior.duplicate(true)` 제거. `BulletBehaviorState`가 다시 복사하므로 중복이지만, `bullet.behavior` 필드가 Shot과 공유되면 기존 격리 테스트가 깨지고 테스트 fixture를 오염시킨다. 비용 절감은 상태 쪽 복사와 함께 다시 설계할 때 다룬다.

## Lab 공통 입구와 패턴 스크립트 작업 환경 — 2026-09-17

- 정본: [전투](../combat.md), [씬 플로우](../scene-flow.md). `labs/lab_hub.tscn`에 탄막·무기/증강·전투 위협도·카드 UI 진입점을 통합. F1 복귀는 Lab 재시작 후에도 유지한다. 기존 특화 탄막 씬은 호환 바로가기다.
- `bullet_lab.gd`에 스크립트 선택/프로젝트 경로·발사 위치·저장본 F5 재로드 연결. `labs/pattern_loader.gd`/`pattern_panel.gd`, 작성용 `patterns/lab_example_pattern.gd` 추가. 기존 사용자 패턴은 수정하지 않았다.
- 오류 시 마지막 정상 패턴 유지, 모달 pause/취소/포커스 복구, 스크립트 모드의 외형/이동 비활성화, 기존 계측 옵션 유지. Inspector·명령행 시작 경로도 제공한다.
- `pattern_lab_smoke_test.gd` PASS: 실제 파일 수정 후 F5 반영·이전 snapshot 격리·파일/문법/상속/필수 생성자/설정 오류·발사 위치·모달 pause/포커스·화면 배치·허브 4개 Lab 왕복·씬 재시작 후 복귀. 의도된 오류 fixture의 문법 오류 로그는 실패와 구분한다.
- D3D12 화면 확인: [공통 입구](../../../artifacts/lab_hub.png), [스크립트 선택](../../../artifacts/pattern_picker.png), [패턴 실행](../../../artifacts/pattern_lab.png). 기존 탄 기초·호밍·Behavior·곡선 레이저·스크립트 패턴 회귀 PASS.
- 최종 포커스 변경 후 패턴 Lab 및 탄 기초 회귀 재확인 PASS. `--pattern=res://patterns/lab_example_pattern.gd` 직접 실행 종료 코드 0, 프로젝트 파싱 및 변경 파일 공백 검사 통과. 테스트에서 생성한 임시 패턴 파일은 정리했다.
- 기존 인증서 저장소·shooting_enemy UID·종료 ObjectDB/리소스 경고는 별도로 남아 있다.

## Lab 위협 계산 토글·FPS 표시 — 2026-09-17

- 정본: [전투](../combat.md). 공통 `bullet_lab.gd`에 위협 계산 ON/OFF와 FPS·평균 프레임 간격 표시 추가. 공통 Lab 진입점 모두 적용.
- OFF에서 ThreatMonitor 자동 샘플링 중단, 상태란의 오래된 수치 제거, 다시 발사/패턴 선택 시 설정 유지. FPS는 pause 중에도 갱신하며 토글/재시작 시 측정 구간 초기화.
- 기존 탄 기초 smoke test에 실제 키보드 토글·샘플 중단/재개·재시작 유지·pause 중 FPS 갱신 검증 추가, D3D12 실행 PASS. [화면 확인](../../../artifacts/bullet_lab_performance.png), 기존 화면 내 배치 검사 및 공백 검사 통과.
- 기존 인증서 저장소·종료 ObjectDB/리소스 경고는 테스트 성공과 별도로 남아 있다.

## 호밍탄 런타임 — 2026-09-17

정본: [전투 — 호밍 런타임](../combat.md#호밍-런타임--구현-완료). 사용법: [API 레퍼런스](../../barrage-api.md#비행-중-표적-추적).

- [x] HOMING Action/builder·검증 및 발사 시 표적/공급자 전달 추가. 기존 enum 번호·정적 Behavior 경로 유지.
- [x] 탄별 동적 실행 상태·입력 기록·과거 보존·미래 재계산을 일반 탄과 레이저 공통 경로에 연결. 발사자 종료 후 잔존 탄 유지.
- [x] 기존 Lab에 호밍 원탄/레이저 선택 및 `projectiles/homing_bullet_lab.tscn` 진입점 추가. 본 게임 무기/적 배정·사용자 mixed_sixteen_pattern은 유지.
- `homing_bullet_smoke_test.gd` PASS: 선회 제한·180도 동률·표적 겹침/소실/재획득·외부 viewport/무효 공급자·유한/무한 반복·즉시 Action·병렬 종료/가속/색·측면 이동 조합·탄별 격리·미래/실제 위치·과거 부분 구간/레이저 꼬리·pause·실제 피격·발사자 삭제·공급자 콜백에서 재생 중단 검사.
- D3D12 실제 렌더링 PASS 및 [호밍 원탄](../../../artifacts/homing_bullet_lab.png), [호밍 레이저](../../../artifacts/homing_laser_lab.png) 확인. WASD로 표적 이동, 방향키/Enter 메뉴, 판정 표시 사용 가능.
- 기존 캐시(1477개 시각)·Behavior·탄 기초·레이저·Barrage API·스크립트 패턴·배치·탄소거·위협 격자 회귀 9종 PASS. 프로젝트 파싱 종료 코드 0, 변경 파일 공백 검사 통과.
- 기존 종료 ObjectDB/리소스·인증서·shooting_enemy UID 경고는 별도이며 잘못된 pattern_script 오류는 의도된 시험이다. 최종 파싱에서 샌드박스 밖 editor_settings 저장 실패도 출력됐으나 스크립트 파싱 실패는 없고 종료 코드 0이다.
- 후속: 외부 증강 효과 API·적탄 개입, 플레이어 무기 이식 및 실제 밸런스 조정. 현재 공통 몸체의 피해 대상은 기존 적탄 연결을 유지한다.

## 후속 작업 — 2026-09-17 (기존 09-18 예정분)

정본: [전투](../combat.md), [증강](../augments.md). 성능 개선 구현과 호밍·외부 개입 설계 기록이다. 이후 호밍 런타임은 위 작업에서 연결했다.

- [x] **Behavior 성능 개선:** Action 경계 누적 상태·이동 채널 전용 평가·위치 조회 재사용 구현. 몸체의 실제 시각과 미래 조회 시각 분리 및 미래 위치 캐시 폐기 접점 추가. 현행 mixed_sixteen_pattern 보존.
- [x] **플레이어 호밍 설계:** 표적 공급/재획득/소실, 선회 제한, 이동 채널 충돌, 관측 위치 기준 예측 정책을 전투 기획서에 반영.
- [x] **플레이어 증강의 적탄 궤도 개입 설계:** 효과 합성/수명, Behavior 적용 순서, 과거 보존·미래 예측 갱신 및 증강의 책임 범위를 정본에 반영.

남은 후속: 외부 효과 핸들 API와 실제 증강 연결. 외부 효과의 세부 메서드명·밸런스 기본값은 미정이며 현재 사용 가능한 API로 해석하지 않는다.

### 성능 개선 검증

- 범위: `projectiles/bullet_behavior_state.gd`, 두 몸체의 재생 시각 전달, `tests/behavior_cache_smoke_test.gd`와 독립 기준 해석기 `tests/fixtures/behavior_reference.gd`, 전투/증강/API 문서. 기존 `feature/bullet-foundations`의 미커밋 작업에서 이어갔다.
- 기존 해석기와 1477개 시각의 전체 상태·위치·속도 비교 PASS. 순차/병렬/유한·무한 반복/즉시 변경/측면 파동/현재 사용자 패턴 포함. 역순 조회, 반환 상태 격리, 예측 폐기 후 재계산, 과거 보존, 조회 캐시 상한 검증. 소수점 Action 경계는 정본의 경계 적용 규칙에 맞춰 기존 해석기의 우극한과 비교한다.
- 반복 패턴의 준비된 `sample` 조회 1000회, 나이 0.5/6/24초: 기존 5.299/16.508/70.913µs → 변경 5.257/5.159/5.157µs/회. 과거 반복 횟수에 비례하던 재해석 비용을 제거했다. 최초 캐시 생성 비용을 포함한 전체 프레임 수치가 아니다.
- 현행 사용자 패턴은 8초 방향 파동과 3초 가속의 병렬 실행이다. 아래 과거 감속 분석 당시 패턴과 달라 이번 수정 전 측정을 새 기준으로 사용했다. `mixed_pattern_diagnostic.gd`, 원탄 8/레이저 8, age=6초: 몸체 2.782→2.475ms, 배치 1.230→1.271ms, 위협 샘플 6.992→4.147ms. age=0.5/2/3.5/6/7.5초 위협 샘플은 기존 4.994/7.968/7.137/6.992/5.732ms → 변경 3.405/4.933/4.321/4.147/3.392ms. 전체 프레임/GPU 시간은 아니다.
- D3D12 Mobile / GTX 1660 Ti / VSync OFF, 각 모드 10초 중 첫 1초 제외: 판정 OFF 중앙값 8.367→8.354ms, p95 13.948→12.618ms; ON 중앙값 8.356→8.351ms, p95 13.930→12.820ms. 단일 전후 실행의 관측값이며 CPU 개선율을 FPS 개선율로 환산하지 않는다.
- 캐시·Behavior·탄 기초·곡선 레이저·Barrage API·스크립트 패턴·배치 렌더러·탄소거·위협 격자 회귀 PASS. 프로젝트 파싱 종료 코드 0. 실제 실행 엔진은 wrapper 출력 기준 Godot 4.7 stable이다.
- 기존 탄 기초 테스트는 편집 가능한 wave 프리셋의 현재 진폭 0과 하드코딩된 기대 진폭 12가 불일치하여 실패했다. 프리셋을 바꾸지 않고 테스트가 명시적으로 비영 진폭 fixture를 생성하도록 수정한 뒤 PASS.
- 기존 종료 ObjectDB/리소스 잔존·인증서 저장소·shooting_enemy UID 경고는 테스트 성공과 별도로 남아 있다. 잘못된 pattern_script 오류는 의도된 거부 시험이다.

## 혼합 패턴 감속/프레임 저하 분석 — 2026-09-17

- 정본: [전투](../combat.md). 사용자 패턴 및 실행 코드는 수정하지 않고 tests/mixed_pattern_diagnostic.gd 비교 측정 추가.
- 현재 speed_to(1.5, 1.0)은 절대 속도 1.5px/s로 감속한다. heading_wave 2.4초 → wait 0.5초 → speed_to 1초 전체가 3.9초 주기로 반복되며, repeat()는 호출 시점의 명령만 감싸지 않는다.
- Headless, 원탄 8/레이저 8 고정, age=6초 구간 CPU 평균: 원래 단일 wave는 pose 2.263ms / batch 1.311ms / threat sample 2.534ms. 수정 패턴은 pose 4.187ms / batch 1.383ms / threat sample 16.431ms. 전체 프레임/GPU/물리 서버 비용을 포함한 수치는 아니다. 위협도 측정은 실제로 0.2초마다 실행된다.
- 원인: 단일 wave 전용 경로 이탈, sample(time)의 과거 Action/반복 재해석과 Dictionary 복사, position_at의 캐시 사이 잔여 적분 재평가. 몸체 37점 및 과거 꼬리+미래 1.2초 경로 조회가 이를 증폭한다. 저속에서도 시간 기준 표본 수는 줄지 않는다.
- D3D12 실제 Lab 10초씩 측정: 판정 OFF 중앙값 12.95ms / p95 42.96ms, ON 12.396ms / p95 56.622ms. 최대값은 각각 246.08/171.576ms로, 해당 최대값의 개별 원인은 별도 분리하지 않았다. 기존 종료 리소스/인증서 경고 발생.
- 후속 제안: 일반 Behavior 상태/구간 캐시와 궤적 표본 재사용을 먼저 개선한 뒤 위협도 예측 및 물리 판정 비용 재측정. 이 분석에서 런타임 최적화는 수행하지 않았다.

## 공통 꼬리 입자 관리기 — 2026-09-17

- 정본: [전투](../combat.md), [Drone](../enemies/drone.md). BulletTrailEffect, BulletTrailEmitter, ProjectileTrailManager 및 GPU 감쇠 셰이더 추가.
- Shot.trail_effect 선택 설정을 일반 탄/레이저에 연결. Drone/바늘탄 Lab에 diamond_trail.tres 배정. 틱 예산/전체 상한/순간이동 보호/월드 좌표/자연 소멸 및 재시작 clear 구현.
- 입자마다 Node 생성 없이 RefCounted 데이터 사용. 생성/소멸 시만 배치 데이터 재업로드하며 셰이더가 위치·크기·색을 시간에 따라 계산한다. 물리 시계이므로 트리 pause에 맞춰 멈춘다.
- projectile_trail_smoke_test PASS: 관리기 공유/월드 격리, 거리 분할, 정지 방출 없음, 설정 격리, 이동하는 부모 좌표, pause/수명, 전체/틱 예산, 순간이동, 실제 탄·레이저 연결, 탄 제거 후 잔여 꼬리, 월드 정리.
- 스크립트 패턴·Behavior·탄소거 회귀 PASS. D3D12 캡처 artifacts/particle_trail_lab.png 확인. 기본 입자 크기는 0.8px로 미세한 꼬리이며 프리셋 size로 조정 가능.
- projectile_trail_benchmark, D3D12 / GTX 1660 Ti: 생성/소멸 없는 유지 CPU 중앙값 256개 0.165ms, 1024개 0.514ms, 4096개 1.911ms. 매 틱 80개 생성, 수명 0.22초, 60Hz 갱신에서 1120개 유지 CPU 중앙값 3.402ms / p95 4.504ms. 모두 단일 효과 1드로우콜. GPU 전체 프레임 시간이 아닌 입자 관리/업로드 구간 측정이다.
- 기존 종료 리소스 및 렌더링 인증서 경고는 별도로 남아 있다.

## 텍스처 바늘탄 — 2026-09-17

- 정본: [전투](../combat.md), [Drone](../enemies/drone.md). BulletAppearance.TEXTURED와 needle.tres 추가. Drone은 새 BULLET 몸체/Behavior 사용.
- 기존 중심 텍스처와 두 가산 발광층을 층별 MultiMesh로 배치. 캐시 키에 텍스처·층 크기·색 포함. 혼합 그리기 순서를 유지하는 CanvasItem RID를 관리하고 트리 이탈 시 해제.
- 직사각형 판정/오프셋/판정 표시 배칭 추가. 시각 크기와 판정 배율 분리. 배칭 OFF 비교 경로도 같은 텍스처 셰이더 사용.
- textured_bullet_smoke_test: 외형·실제 직사각형 충돌·시각/판정 확대 분리 PASS. D3D12/OpenGL 렌더링 PASS 및 artifacts/textured_bullets.png 확인. D3D12의 바늘탄 20발+판정 표시 총 4드로우콜(외형 3층+판정 1).
- 배치 렌더러·스크립트 패턴·Behavior·탄소거 회귀 PASS. 기존 혼합 원탄/레이저 화면도 재확인. git diff --check 통과. 인증서/셰이더 캐시 및 종료 리소스 경고는 별도로 남아 있다.
- 파티클 꼬리와 초기 확대/섬광은 이식 범위 밖. 시험 진입점 projectiles/textured_bullet_lab.tscn, Lab의 바늘탄 선택으로 직선/파동 비교 가능.

## Motion 제거 및 기존 탄 외형 복원 — 2026-09-17

- 정본: [전투](../combat.md), [Drone](../enemies/drone.md).
- BulletMotion 클래스/UID, straight.tres/wave.tres 삭제. BarrageShot/FoundationBullet.motion 및 from_motion 제거. 저장된 씬·회전 링·Lab·테스트를 Behavior 프리셋으로 이관.
- Drone .gd 일정은 유지하고 Kind.LEGACY를 사용하여 기존 Sprite/발광/파티클/판정 복원. 원탄·쌀탄·레이저 시험 예제는 선택 가능한 새 외형으로 유지.
- 탄 기초·Behavior·Barrage API·배치 렌더러·스크립트 패턴 회귀 PASS. Drone의 기존 Sprite/Trail 실제 생성 검사 추가. 스크립트 패턴의 잘못된 입력 오류 로그는 의도된 시험 결과.

## .gd 패턴 실행 — 2026-09-17

- 정본: [전투](../combat.md), [Drone](../enemies/drone.md). 사용 계약: [API 레퍼런스](../../barrage-api.md).
- BarrageSequence 상속 패턴 두 개 추가: patterns/drone_pattern.gd, patterns/mixed_sixteen_pattern.gd. Drone과 혼합 시험의 실행 원본 전환.
- EnemyShootComponent에 pattern_script 검증·내부 Player·초기 활성화 연결 추가. 레거시 필드는 Inspector 그룹으로 구분하고 패턴 모드에서 무시.
- Player에 발사 허용 콜백·표적 재조회·일정 배속, Sequence에 생성자를 재실행하지 않는 snapshot 및 발사 요약 추가. 외부 Resource까지 복사하여 공유 프리셋 격리.
- script_pattern_smoke_test PASS: 두 적의 상태/내부 Behavior 격리, 초기 지연/화면 진입, 금지선 건너뛰기, 표적 재획득, 일정 배속/위협 보고, 일시정지, 활성 기간 종료, 적 제거, 생성자 재실행 방지, 조준/비조준 혼합, 잘못된 스크립트 거부. 잘못된 스크립트 테스트의 오류 로그는 의도된 검증 결과.
- 기존 Barrage API·Behavior 혼합 장면·위협도·사격 금지선·버스트·전용 자율 씬·탄 생성 어댑터·탄소거 보상·Interceptor 회귀 PASS.
- D3D12 Mobile / GTX 1660 Ti, VSync OFF, 각 10초(처음 1초 제외) 재측정: 혼합 패턴 OFF 중앙값 9.92ms / p95 14.40ms, ON 10.74ms / p95 14.08ms. 이전 9.72/10.56ms 중앙값과 비슷한 범위이며 최대 프레임은 OFF 21.94ms / ON 18.12ms. 노드/물리 비용이 제거된 것은 아님.
- 종료 리소스/RID 잔존, 기존 Caster UID, 렌더링 인증서 메시지는 별도로 남아 있다.

## Drone 첫 연결 — 2026-09-16

- 정본: [Drone](../enemies/drone.md), [전투](../combat.md).
- 선택적 EnemyShootComponent.barrage_shot 연결, deferred 생성 및 사라진 발사자/월드 검사 추가.
- Drone 직선 원탄 전환, 상속하는 Interceptor는 기존 탄 유지. Timer·조준·발사 금지선·강화 배율 보존.
- enemy_barrage_shot_smoke_test: 실제 Drone 생성, 월드 좌표/조준/속도, 배치 렌더링, 강화 배율, 금지선, 부채꼴 발수, 발사자 제거 및 잔존 탄 PASS.
- 기존 사격 금지선·버스트·자율 전용 씬·탄소거 보상 회귀 PASS. 종료 RID/ObjectDB/리소스 잔존 경고는 별도 기록.

## API 문서 정리 — 2026-09-16

- 사용자 요청에 따라 [API 레퍼런스와 본 게임 이식 안내](../../barrage-api.md)를 별도 작성.
- Shot·Appearance·Action·Behavior·Volley·Step·Sequence·Player 구현과 기본값·제한·좌표·수명 계약을 대조.
- 기존 일반 사격/Caster/강화 배율/위협도 연결을 조사하여 단계별 이식 제안과 동작 차이 기록. 이식 제안은 미구현이며 게임 코드·적 배정 변경 없음.
- 문서 링크 대상 존재 여부 및 `git diff --check` 확인. 문서만 변경하여 런타임 시험은 재실행하지 않음.

정본: [전투 — 탄막 작성 API](../combat.md#탄막-작성-api--1차-구현-완료)

## 작업 범위

- [x] `projectiles/barrage_*.gd`: 탄/배치/단계/시퀀스 Resource와 실행기.
- [x] `projectiles/bullet_lab.gd`: 기존 발사 루프를 공통 API로 이관.
- [x] `resources/projectiles/rotating_ring_sequence.tres`, `projectiles/barrage_api_lab.tscn`: 저장 가능한 예제와 시험 진입점.
- [x] `tests/`: API 회귀 추가, 기존 시험의 발사 중단/재개를 새 실행기로 연결.
- [x] 전투 문서에 API 계약과 사용 예제 반영.

## 검증

- `barrage_api_smoke_test.gd`: 배치의 중심각/끝점, 실제 발수·생성 위치, 시간 분할·따라잡기, 반복 종료·재시작, 깊은 Resource 격리, 실행기/트리 일시정지, 매회 조준, 표적/발사자 삭제, 잔존 탄, 잘못된 설정, 진행 예산, 신호에서 중단, 저장된 예제 실행 PASS.
- 기존 `bullet_foundations_smoke_test.gd`, `curved_laser_smoke_test.gd` PASS.
- 탄소거 보상·위협도·배치 렌더러 회귀 테스트 PASS.
- 마무리 점검에서 생명주기 이벤트를 연결: 일시정지 중 트리 이탈 즉시 취소, 재진입 시 자동 재개 방지, 재생 교체 후 이전 발사자의 이벤트 연결 해제를 회귀 테스트에 추가.
- OpenGL 실제 렌더링 API 테스트 PASS. [회전 링 예제 화면](../../../artifacts/barrage_api_lab.png)에서 메뉴·패턴을 확인.
- 프로젝트 기본 D3D12 Mobile 렌더러에서도 API 테스트 PASS. 프로젝트 파싱 검사 및 `git diff --check` 통과.
- Headless 종료 리소스 잔존 경고 및 OpenGL 인증서 저장소 메시지는 테스트 PASS/종료 코드와 별도로 남아 있다.
- 이번 작업은 기존 `feature/bullet-foundations`에서 계속 진행했으며 본 게임 적 배정은 변경하지 않았다.

## 탄별 Behavior 후속 구현 — 2026-09-16

정본: [탄별 Behavior와 몸체 분리](../combat.md#탄별-behavior와-몸체-분리--구현-완료)

- [x] `BulletAction`, `BulletBehavior`, 탄별 실행 상태와 공유 궤적 조회 구현.
- [x] 일반 탄/레이저에 같은 Behavior 연결, 기존 이동 설정 호환 변환.
- [x] 색·투명도·시각 배율을 배치 렌더러에 전달하고 판정 배율과 분리.
- [x] Sequence 동시 Volley 및 링/부채꼴 편의 API 추가.
- [x] 저장 프리셋, 16방향 혼합 예제 및 색/크기 예제 시험 씬 추가.
- [x] Behavior 일정·병렬·반복·설정 격리·실제 충돌·예측/과거 경로 회귀 PASS.
- [x] 기존 탄 기초·레이저·탄막 API·배치 렌더러·탄소거 보상·위협도 회귀 PASS.
- [x] OpenGL 및 기본 D3D12 Mobile에서 Behavior 시험 PASS, 프로젝트 파싱 종료 코드 0.
- [x] [혼합 발사](../../../artifacts/mixed_sixteen_lab.png), [색/크기 변경](../../../artifacts/behavior_visual_lab.png) 실제 렌더링 확인.
- 종료 시 ObjectDB/리소스 잔존 메시지와 기존 shooting_enemy UID 경고는 별도로 남아 있다. 이번 작업에서 성능 벤치마크 수치를 다시 측정하지 않았다.

## 프레임 저하 보정 — 2026-09-16

- 원인: 위치 조회마다 Behavior Dictionary 생성·전체 액션 평가, 위협 격자의 모든 칸과 모든 곡선 선분을 반복 비교.
- 측면 변위가 없는 궤적의 불필요한 상태 평가 제거, 단일 방향 파동의 직접 계산 추가. 일반 타임라인과 유한/무한 반복 경계 궤적 일치 회귀 PASS.
- 위협 격자는 각 선분의 반경 포함 경계 안에 있는 칸만 거리 검사. 80개 고정 난수 경로와 길이 0인 선분을 기존 전수 검사와 비교하여 점유율 일치 PASS.
- `behavior_performance_benchmark.gd`: 혼합 16발, 나이 2~3초, 20회 준비 후 100회 평균. Headless CPU 측정에서 판정 표시 OFF 기준 몸체 갱신 6.58→2.38ms, 배치 구성 1.65→1.33ms, 위협 샘플 48.19→3.14ms. ON 기준 6.79→2.32ms, 2.38→1.85ms, 47.04→2.91ms. 매 프레임 위협 샘플을 강제한 분리 측정이므로 합계를 실제 프레임 시간으로 해석하지 않는다.
- 같은 스크립트 `-- --live`: 기본 D3D12 Mobile / GTX 1660 Ti, VSync OFF, 각 모드 10초 실시간 재생(초기 1초 제외). OFF 프레임 중앙값 9.72ms / p95 14.17ms / 최대 18.27ms. ON 10.56ms / p95 14.03ms / 최대 18.32ms. 수정 전 실시간 FPS 자료는 없으며 CPU 개선율을 FPS 개선율로 환산하지 않는다.
- Behavior·기존 곡선 레이저·위협도·격자 동등성 테스트 PASS, `git diff --check` 통과. 기존 종료 리소스 잔존 및 인증서 저장소 메시지는 남아 있다.
