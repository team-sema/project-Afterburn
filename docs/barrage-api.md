# 탄막 API 레퍼런스와 본 게임 이식 안내

코드 확인: 2026-09-17. 현재 구현된 API의 사용 설명이다. 게임 규칙의 정본은 [전투 기획서](design/combat.md)이다. 별도 API 문서를 요청한 데 따라 사용 계약을 모아 두었다. API 변경 시 이 문서도 함께 갱신한다.

## 시작하기: 적에 .gd 패턴 지정하기 (2026-09-17)

먼저 패턴만 시험하려면 [`labs/lab_hub.tscn`](../labs/lab_hub.tscn)을 F6으로 열고 **탄막 · 패턴 스크립트**를 선택한다. 왼쪽 위 **스크립트 열기**에서 `patterns/` 파일이나 `res://...gd` 경로, 발사 위치를 지정한다. [`lab_example_pattern.gd`](../patterns/lab_example_pattern.gd)를 복사해 작성할 수 있다.

편집기에서 저장하고 **실행 창에서 F5**를 누르면 새 생성자로 패턴을 다시 만들고 탄·꼬리·계측을 초기화한다. 문법/상속/설정 오류는 화면에 표시하며 취소하면 마지막 정상 실행으로 복귀한다. `_init` 내부의 임의 런타임 오류는 Godot Output에서도 확인한다. 재로드 대상은 선택한 `.gd`이며 참조한 외부 리소스는 Godot의 기본 캐시 정책을 따른다. 외형·이동은 스크립트가 정하고 Lab의 해당 선택기는 비활성화된다.

WASD 표적, 위협 계산 ON/OFF, FPS/ms, 판정 표시, pause, 탄소거를 함께 쓸 수 있다. 허브에서 열었다면 F1로 목록에 돌아온다. Inspector의 `test_pattern_path` 지정 또는 `tools/run-godot.cmd res://projectiles/bullet_lab.tscn -- --pattern=res://patterns/lab_example_pattern.gd`로 바로 실행해도 된다. 기존 특화 Lab 씬은 동일 화면의 예제별 바로가기다.

기본 작성 방식은 BarrageSequence를 직접 상속하는 `.gd`다. 실행 중 await하는 스크립트가 아니라 발사 일정을 구성하는 스크립트다. 인자 없는 `_init()`에서 설정만 만들며 월드 접근·실제 발사 같은 부수 효과를 넣지 않는다.

```gdscript
extends BarrageSequence

func _init() -> void:
    var shot := BarrageShot.new()
    shot.appearance = preload("res://resources/projectiles/round.tres")
    shot.behavior = BulletBehavior.new().wait(0.5).turn_by(90, 1.0)
    fire_ring(shot, 12, 95.0)
    wait(0.4)
    rotate(10)
    repeat()
```

1. 스크립트를 `patterns/` 아래 저장한다.
2. 적 씬의 EnemyShootComponent → **Pattern → Pattern Script**에 `.gd`를 지정한다.
3. Activation의 initial_delay, activate_on_visible_entry, active_duration, apply_shot_threshold를 설정한다. 조준 Volley는 기존 targeting_component를 사용한다.
4. 패턴 모드에서는 Legacy fire의 간격·버스트·발수·탄속·탄 설정과 legacy 방향 주입 옵션이 적용되지 않는다. 발사 내용은 `.gd`에서 정한다.

수치를 적 씬에서 바꾸려면 `_init()` 대신(또는 함께) `build(params: Dictionary)`를 구현한다. 컴포넌트는 `_init()` 다음에 **Pattern → Pattern Params** Dictionary를 `build()`로 넘기고, 그 뒤에 검증·발사 요약·snapshot을 수행한다. Lab은 빈 Dictionary를 넘기므로 모든 키를 기본값과 함께 읽는다.

```gdscript
extends BarrageSequence

func build(params: Dictionary) -> void:
    var shot := BarrageShot.new()
    shot.appearance = preload("res://resources/projectiles/round.tres")
    shot.behavior = BulletBehavior.new()
    fire_ring(shot, int(params.get("count", 12)), float(params.get("speed", 95.0)))
    wait(float(params.get("interval", 0.4)))
    repeat()
```

컴포넌트가 내부 BarragePlayer를 생성한다. 별도 실행 코드는 필요 없다. 잘못된 상속/필수 생성자 인자/잘못된 일정은 pattern_error와 오류 로그로 보고하며 레거시 사격으로 대체하지 않는다. pattern_script 선택은 씬 시작 시 적용하며 실행 중 필드 교체를 통한 자동 재시작은 지원하지 않는다.

- 실제 Drone: [drone_pattern.gd](../patterns/drone_pattern.gd). Kind.BULLET과 needle.tres로 텍스처 바늘탄을 조준 단발로 발사한다. 105px/s, 4.5초 간격. 최초 1.5초 지연은 적 씬에 있다.
- 조준 고정 연발 예제: [locked_burst_pattern.gd](../patterns/locked_burst_pattern.gd). `aim()` 뒤 `Aim.LOCKED` 바늘탄 3발(0.12초 간격) → 2초 휴식 → 반복. `build(params)`로 `shots`, `gap`, `rest`, `speed`를 씬에서 조정할 수 있다. 본 게임 적에는 배정하지 않았다.
- 조준 부채꼴 연발 예제: [aimed_fan_burst_pattern.gd](../patterns/aimed_fan_burst_pattern.gd). 5방향 40° 부채꼴의 중앙 탄이 매 발사 표적을 향하는 `Aim.EACH_SHOT`, 0.15초 간격 5연발 → 1.6초 휴식 → 반복. `ways`, `spread`, `shots`, `gap`, `rest`, `speed`를 `build(params)`로 조정. 본 게임 적에는 배정하지 않았다.
- 16방향 혼합 시험: [mixed_sixteen_pattern.gd](../patterns/mixed_sixteen_pattern.gd). 이 `.gd`가 현재 시험 씬의 실행 원본이다. 예전 `.tres`는 저장 형식 호환 예제로 남겨 둔다.
- 발사 금지선에서는 FIRE를 건너뛰고 다음 일정으로 진행한다. 표적 부재 시 조준 Volley만 건너뛰며 다음 FIRE에서 재조회한다. 공격 기간 종료·적 제거는 미래 발사를 중단하고 기존 탄은 유지한다.
- ACTION_RATE는 Player.time_scale에 적용한다. 초기 지연과 활성 기간은 게임 시간이며 이미 발사한 탄의 이동은 바뀌지 않는다.
- 위협 보고는 한 주기 발수/대기 총합(최소 0.05초)에 배속을 곱하고 가장 빠른 초기 탄속을 사용한다. 초기 대기 중에도 예정 공격을 보고하며 자연 종료 후에는 0이다. 이것은 실제 발사 실적이나 임의 Behavior의 정확한 위험도 계산이 아니다.

### Player / Sequence 추가 API

- `BarrageSequence.snapshot()`: 기본 BarrageSequence에 단계와 외부 프리셋(Shot·Appearance·Behavior·Action·Volley·TrailEffect)까지 복사한다. 텍스처 같은 자산 Resource는 복사하지 않고 공유한다. 배치 렌더러와 꼬리 관리기가 텍스처 RID로 묶음을 나누므로, 텍스처를 복제하면 발사자마다 별도 드로우콜로 갈라지고 재생마다 GPU 업로드가 생긴다. 상속 Sequence 생성자를 다시 실행하지 않는다. 유효한 Sequence에서 호출한다. `BarrageSequence.clone_settings(resource)`는 같은 규칙의 단일 Resource 복사다.
- `BarrageSequence.emission_summary()`: 유효한 일정의 `rate`, `speed` 요약을 반환한다.
- `BarrageSequence.build(params)`: 기본 구현은 빈 훅. 파생 패턴이 재정의하면 컴포넌트/Lab이 `_init()` 다음에 호출한다.
- `BarrageSequence.needs_target()`: `aim()` 단계 또는 `aim != NONE`인 Volley가 있으면 true. Player가 표적 요구 검증에 사용한다.
- `BarragePlayer.time_scale = 1.0`: 양수 배속. 비유한/0 이하이면 진행하지 않는다.
- `BarragePlayer.may_fire: Callable`: 인자 없이 bool 반환. false인 FIRE는 건너뛴다.
- `BarragePlayer.resolve_target: Callable`: 인자 없이 Node2D 또는 null 반환. 조준 발사가 있는 Sequence는 FIRE마다 조회한다. 호밍탄에는 같은 공급자를 전달하며 탄이 표적을 잃었을 때 재조회한다. 지정 시 play의 고정 target은 필수가 아니고 표적 이탈로 전체 패턴을 중단하지 않는다. 미지정 시 기존 고정 조준 표적 계약을 유지한다. 콜백은 빠른 표적 조회에 사용한다.

## 1. 구성과 단위

- `BarrageShot`: 무엇을 발사할지. 몸체 Kind, 외형, Behavior, 수명.
- `BulletAppearance`: 일반 탄의 기본 그림과 기본 판정.
- `BulletBehavior`: 발사된 탄 하나의 시간에 따른 이동·속성 변화.
- `BulletAction`: Behavior의 한 단계. 병렬 그룹의 구성 단위이기도 하다.
- `BarrageVolley`: 한 번에 발사할 탄의 배치·발수·속도·각도·조준.
- `BarrageSequence`: Volley를 언제 발사할지. 대기·발사 기준각 회전·반복.
- `BarragePlayer`: Sequence를 실행하는 Node. 나머지 설정 클래스는 저장 가능한 Resource다.

시간은 초, 거리·크기는 px, 속도는 px/s, 각도는 도다. `lateral_wave`의 위상만 라디안이다. 아래 방향이 0°이며 양수 회전은 Godot 2D 회전을 따른다. 예를 들어 아래에서 +90°는 왼쪽이다. 발사 위치와 방향은 월드 좌표, Volley의 `origin_offset`은 발사자 로컬 좌표다.

Sequence의 시간은 발사 일정, Behavior의 시간은 **각 탄이 발사된 순간부터의 나이**다. `sequence.rotate()`는 이후 발사 방향을 바꾸고, `behavior.turn_by()`는 이미 발사된 탄의 이동 방향을 바꾼다.

## 2. BarrageShot

소스: [barrage_shot.gd](../projectiles/barrage_shot.gd)

### 몸체와 공통 설정

- `kind = Kind.BULLET`: 일반 탄. `appearance`와 `behavior`를 지정한다.
- `Kind.TRAIL_LASER`: 머리의 과거 궤적을 몸통으로 남기는 레이저. 직선·선회·S자 이동 모두 같은 몸체다. `appearance`는 적용하지 않는다.
- `Kind.LEGACY`: 기존 `base_enemy_projectile.tscn` 비교용 어댑터. Behavior를 지정할 수 없다.
- `Kind.CURVED_LASER`: `TRAIL_LASER`와 같은 값인 호환 별칭. 새 코드에는 `TRAIL_LASER`를 사용한다.
- `behavior: BulletBehavior`: 발사 후 행동. 빈 `BulletBehavior.new()`는 직진이다.
- `lifetime = 5.0`: 수명. 유한한 양수. Behavior가 끝나도 탄은 마지막 상태로 수명까지 움직인다. 기존 화면 이탈 제거도 적용된다.

### 레이저 설정

- `core_width = 6.0`: 기본 시각 두께. 발광층은 코어보다 넓다.
- `hit_width = 4.0`: 기본 판정 두께. 양수이고 `core_width` 이하여야 한다.
- `trail_duration = 1.4`: 몸통으로 유지할 과거 시간. 양수.
- `lifetime = 5.0`: 레이저 수명.

몸통은 양 끝이 가늘어지는 형태다. 시각 두께와 판정 두께는 독립이며, Behavior의 각 배율을 곱한다. `visual_scale_to(2, 1)`은 1초 동안 시각 **두께**를 2배로 만든다. 궤적 길이나 이동 속도를 2배로 만들지는 않는다. 레이저의 길이는 이동 궤적과 `trail_duration`으로 정해진다.

### 메서드

```gdscript
is_valid() -> bool
spawn(parent: Node2D, origin: Vector2, direction: Vector2,
      speed: float, debug := false, target: Node2D = null,
      target_resolver := Callable()) -> Node2D
```

`spawn`은 월드 좌표에서 한 발을 생성·발사하고 노드를 반환한다. 실패하면 `null`. 부모는 트리 안에 있어야 한다. 방향은 유한한 0이 아닌 벡터, 속도는 유한한 0 이상이며 레이저의 초기 속도는 0보다 커야 한다. 통상 발사는 Sequence/Player를 사용하고 단발 연결에 이 메서드를 사용할 수 있다.

### 이전 설정 호환

Motion 호환 클래스·필드·프리셋은 제거했다. 일반 탄에는 behavior를 반드시 지정하고 수명은 shot.lifetime으로 정한다. 직진은 BulletBehavior.new(), 파동은 lateral_wave(...).repeat()로 작성한다. 레이저에 behavior가 없으면 turn_degrees = 70.0(도/초), turn_duration = 1.5를 Behavior로 변환하는 별도 호환 경로는 유지한다.

기존 탄 외형을 그대로 사용하려면 `var shot := BarrageShot.new()` 다음 `shot.kind = BarrageShot.Kind.LEGACY`를 지정한다. 별도의 appearance나 behavior는 지정하지 않는다. Volley와 Sequence는 그대로 사용할 수 있지만 이 몸체는 새 MultiMesh 렌더링·Behavior를 지원하지 않는다. 중심 Sprite와 두 발광층은 아래 TEXTURED 외형으로 새 렌더러에서 지원하며 파티클은 별도 작업이다.

## 3. BulletAppearance

### 선택적 꼬리 효과: BulletTrailEffect

```gdscript
shot.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
```

BULLET과 TRAIL_LASER의 머리에 적용한다. 기본값 null은 효과 없음이며 LEGACY 몸체에 지정하면 유효성 검사에서 거부한다. 탄 부모는 Node2D 월드여야 한다. 발사 시 효과 설정을 복제한다.

- `texture`: 입자 텍스처. 기본 프리셋은 기존 particle_diamond.svg.
- `spacing = 2.0`: 이동 거리 2px마다 입자 하나. 최소 0.25px. 정지 중 방출 없음.
- `lifetime = 0.22`: 입자 수명, 0 초과 5초 이하.
- `size = 0.8`, `end_size = 0.1`: 입자의 시작/끝 사각형 크기(px). 시작은 양수, 끝은 0 이상, 최대 128px.
- `speed_min = 8`, `speed_max = 14`: 이동 반대 방향으로 입자가 흘러가는 속도 범위(px/s), 0~1000.
- `spread_degrees = 6`: 반대 방향 기준 ±퍼짐각, 0~180°.
- `color`, `end_color`: 시작/끝 색과 투명도. 선형 보간하며 기본은 분홍에서 어두운 투명색으로 감쇠한다. 탄 Behavior의 tint/opacity와 별개다.

관리기는 월드당 하나이며 같은 텍스처·색·크기 설정끼리 한 MultiMesh로 묶는다. 입자 이동·색·크기 감쇠는 셰이더, 수명/방출 예산은 CPU가 관리한다. 트리 일시정지에서 정지하며 탄이 없어져도 기존 입자는 남는다. 장식 입자는 충돌·탄소거 보상·위협도에 포함하지 않는다.

최대 4096입자/월드, 신규 256개/물리 틱, 탄당 64개/갱신. 초과 방출은 버리고 다음 틱에 보충하지 않는다. 한 번에 1024px 넘는 이동은 순간이동으로 취급한다. 굴곡은 물리 틱의 이전/현재 위치 사이 선분으로 근사한다. `ProjectileTrailManager.clear()`로 잔여 입자를 즉시 지울 수 있고 Lab 재시작은 이를 호출한다. 일반 탄 소거는 꼬리가 자연스럽게 사라지게 둔다.

Drone과 바늘탄 시험에 연결되어 있다. 기존 GPUParticles2D를 그대로 실행하는 것이 아니라 다이아몬드 질감을 공통 관리기로 재현한 것으로, 기존의 시간당 방출과 정확히 같은 결과는 아니다.

TEXTURED 외형이 추가되었다. `form = BulletAppearance.Form.TEXTURED`, `texture: Texture2D`를 지정하면 기존 스프라이트를 새 BULLET 몸체와 Behavior에서 사용할 수 있다. `core_size`, `wide_size`, `tight_size`는 세 층의 px 크기, `core_color`, `wide_color`, `tight_color`는 각 층 색이다. `tint`와 Behavior의 tint는 이 층 색에 곱한다. 기본 tint를 흰색으로 두면 원래 층 색을 유지한다.

TEXTURED는 `collision_size`(양수 Vector2)의 직사각형 판정과 `collision_offset`을 사용한다. 시각 확대는 판정을 바꾸지 않고 hitbox_scale은 판정 크기와 오프셋을 함께 확대한다. 현재 발광 블러/강도는 기존 효과와 동일한 넓은 층 9/0.8, 좁은 층 2.5/1.15로 고정이다. 새 프리셋은 `resources/projectiles/needle.tres`, 시험 씬은 `projectiles/textured_bullet_lab.tscn`이다.

Drone은 이제 Kind.BULLET + needle 외형 + 직진 Behavior를 사용한다. 다이아몬드 꼬리는 공통 입자 관리기로 재현하며 초기 확대/섬광은 포함하지 않는다. Kind.LEGACY는 기존 전체 씬 비교가 필요한 경우에만 사용하며 새 외형의 이름은 ‘바늘탄’이다.

소스: [bullet_appearance.gd](../projectiles/bullet_appearance.gd)

- `form = Form.ROUND`: 원탄. `Form.RICE`는 쌀탄, `Form.TEXTURED`는 텍스처 탄이다.
- `core_size = Vector2(8, 8)`: 기본 시각 크기. 각 축은 양수.
- `collision_radius = 3.0`: 원 또는 캡슐의 판정 반지름. 양수.
- `collision_height = 6.0`: 쌀탄의 캡슐 전체 높이. 지름 이상이어야 한다. 현재 검증은 원탄에도 이 조건을 적용한다.
- `tint = Color(1.0, 0.22, 0.52)`: 기본색.
- `is_valid()`, `make_shape()`, `bounding_radius()`: 검증·판정 모양 생성·외접 반경 조회.

`core_size`를 변경해도 판정 크기는 자동 변경되지 않는다. 원탄과 작은 원탄은 별도의 Kind가 아니라 같은 Form의 다른 설정이다.

## 4. BulletBehavior / BulletAction

소스: [bullet_behavior.gd](../projectiles/bullet_behavior.gd), [bullet_action.gd](../projectiles/bullet_action.gd)

다음 builder는 모두 자기 자신을 반환하므로 이어 쓸 수 있다. 순서대로 실행하며 기간 0은 즉시 적용한다(호밍은 양수 기간 필수). 보간은 선형이다.

```gdscript
then(action: BulletAction)
wait(seconds: float)
turn_by(degrees: float, seconds: float)
turn_to(degrees: float, seconds: float)
turn_at(degrees_per_second: float, seconds: float)
homing(max_turn_degrees_per_second: float, seconds: float)
heading_wave(degrees: float, seconds: float)
lateral_wave(amplitude: float, seconds: float, phase := 0.0)
speed_to(speed: float, seconds: float)
tint_to(color: Color, seconds: float)
opacity_to(alpha: float, seconds: float)
visual_scale_to(scale: float, seconds: float)
hitbox_scale_to(scale: float, seconds: float)
parallel(group: Array[BulletAction])
repeat(times := 0)
eased(transition: Tween.TransitionType, ease := Tween.EASE_IN_OUT)
validation_error() -> String
```

- `wait`: 속성을 바꾸지 않고 기다린다. 이동은 계속된다. 정지는 `speed_to(0, ...)`로 지정한다.
- `eased`: **직전에 추가한 Action**에 easing을 적용한다. 대상은 `turn_by`, `turn_to`, `speed_to`, `tint_to`, `opacity_to`, `visual_scale_to`, `hitbox_scale_to`다. `turn_at`(일정 각속도)·파동·호밍·wait는 무시한다. 직전 Action이 없거나 `parallel`이면 경고만 내고 아무것도 바꾸지 않는다. 병렬 자식은 `BulletAction.turn_by(90, 1).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)`처럼 자식마다 지정한다. 기본은 선형이며 endpoints는 바뀌지 않는다. 모든 적용 채널의 보간 비율을 0~1로 제한하므로 BACK·ELASTIC·SPRING의 범위 밖 오버슈트는 잘린다. 예: `speed_to(0, 1).eased(Tween.TRANS_QUAD, Tween.EASE_IN)`은 초반에 속도를 오래 유지하다가 급감한다.
- `turn_by`: 현재 방향에서 지정 각도만큼 선회.
- `turn_to`: 아래=0°인 월드 방향으로 최단 선회.
- `turn_at`: 지정 기간 동안 일정 각속도로 선회.
- `homing`: 지정 기간 동안 표적을 추적한다. 양수 최대 선회율(도/초)과 양수 기간을 명시한다. 표적 부재/겹침 시 방향 유지, 소실 시 선택적 공급자로 재획득. 종료 후 실제 방향을 유지한다. 다른 방향 Action과 같은 병렬 그룹에 넣을 수 없다.
- `heading_wave`: **Action 시작 시점의 heading**을 중심으로 ±진폭의 방향 파동을 한 주기 실행한다. 두 번째 인자는 주기다. `.repeat()`를 붙이면 계속 S자를 그린다. `turn_by(40, 0).heading_wave(20, 1)`은 40° 방향을 중심으로 20°~60°를 왕복한다. (2026-09-17 이전에는 최초 발사 방향이 중심이었다. 위상 0으로 한 주기를 마치는 기본 파동은 결과가 같다. 직접 지정한 위상·기간 때문에 종료 각도 오프셋이 남으면 다음 반복의 중심에 누적된다.)
- `lateral_wave`: 최초 발사 방향에 수직인 축으로 한 주기 동안 변위를 더한다. 기본 전진 속도와 별개다.
- `speed_to`: 속도를 지정값으로 바꾼다. 0 이상.
- `tint_to`: 일반 탄은 기본색을 바꾼다. 레이저는 기존 금색 팔레트에 곱할 색을 바꾼다(초기 흰색). 따라서 레이저에 파란색을 지정한 결과는 순수한 파란색과 다를 수 있다.
- `opacity_to`: 전체 투명도 0~1. 투명해져도 판정과 수명은 유지된다.
- `visual_scale_to` / `hitbox_scale_to`: 각각 시각·판정 배율. 0 초과 16 이하. 서로 자동 연동되지 않는다.
- `repeat(n)`: Behavior 전체를 총 n번 실행. 기본값 1, 0은 무한. 마지막 상태는 다음 반복으로 이어진다. 예: `turn_by(30, 1).repeat(3)`은 총 90° 선회한다.
- `parallel`: 가장 긴 자식이 끝나면 다음 단계로 간다. 짧은 자식은 완료값을 유지한다. 같은 속성에 동시에 쓰는 액션과 중첩 병렬은 거부한다. 선회와 방향 파동은 모두 같은 방향 속성이다.

인스펙터에서는 `actions: Array[BulletAction]`, `repeat_count`를 편집한다. 최대 128단계, 반복 횟수 0~10000, 병렬 자식 1~16개다. 파동 주기는 최소 0.1초, 무한 반복의 전체 기간도 최소 0.1초다. 유효하면 `validation_error()`는 빈 문자열이다.

병렬용 액션 생성:

```gdscript
BulletAction.turn_by(degrees, seconds)
BulletAction.homing(max_turn_degrees_per_second, seconds)
BulletAction.tint_to(color, seconds)
BulletAction.visual_scale_to(scale, seconds)
BulletAction.hitbox_scale_to(scale, seconds)
BulletAction.make(type, value, seconds)
```

`Type`: `WAIT`, `TURN_BY`, `TURN_TO`, `TURN_AT`, `HEADING_WAVE`, `LATERAL_WAVE`, `SPEED`, `TINT`, `OPACITY`, `VISUAL_SCALE`, `HITBOX_SCALE`, `PARALLEL`, `HOMING`. 기존 저장 enum 번호는 유지한다.

직접 편집할 수 있는 필드는 `type`, `duration`, `value`, `period`, `phase`, `color`, `children`, `transition_type`, `ease_type`이다. `make`는 `period`를 자동 설정하지 않으므로 파동 액션을 직접 만들면 `period`도 지정한다. `BulletAction`의 나머지 메서드는 `eased(transition, ease)`(자기 자신 반환), `uses_easing()`, `progress(elapsed)`, `channel()`, `length()`, `validation_error()`다.

### 색·두께와 선회를 함께 변경

```gdscript
var shot := preload("res://resources/projectiles/crescent_laser_shot.tres").duplicate(true) as BarrageShot
shot.core_width = 10.0
shot.hit_width = 4.0
shot.behavior = BulletBehavior.new().wait(0.3).parallel([
    BulletAction.turn_by(90, 1.2),
    BulletAction.visual_scale_to(2.0, 1.2),
]).wait(0.3).opacity_to(0.0, 0.7)
```

이 예제의 판정 두께는 유지된다. 발사 후 외부에서 Behavior를 교체·취소하거나 임의 콜백을 실행하는 API는 아직 없다.

실행기는 Action 경계의 누적 상태와 탄별 궤적 표본을 재사용한다. 과거·미래 조회는 실제 탄 나이를 전진시키지 않으며, 몸체·판정·위협도는 같은 위치 계산을 사용한다. 경계의 1e-10초 이내 부동소수점 오차는 경계 시각으로 처리한다. 외부 효과 적용 API는 아직 제공하지 않는다.

### 비행 중 표적 추적

```gdscript
var shot := BarrageShot.new()
shot.appearance = preload("res://resources/projectiles/round.tres")
shot.behavior = BulletBehavior.new().homing(90, 4)
shot.lifetime = 6
var sequence := BarrageSequence.new().fire_fan(shot, 3, 80, 70).wait(2).repeat()
# aimed 설정 없이도 발사 후 추적한다.
runner.play(sequence, emitter, world, target)
# 재획득이 필요하면 play 전에 runner.resolve_target에
# 인자 없이 같은 viewport의 Node2D 또는 null을 반환하는 Callable을 지정한다.
# 단발: shot.spawn(world, origin, direction, 70, false, target, target_resolver)
```

표적은 탄마다 유지하며 사라지거나 트리/viewport를 이탈하면 공급자를 실제 틱당 최대 한 번 호출한다. 공급자도 사라지면 현재 방향으로 계속 비행한다. 살아 있는 표적의 교체 정책은 이 API에 포함하지 않는다. `aimed`는 발사각 조준만 제어하며 호밍과 독립이다. 일반 탄과 TRAIL_LASER 모두 사용할 수 있다.

예측은 마지막으로 관측한 표적 위치를 고정한 근사다. 표적의 다음 움직임을 미리 알지는 못한다. 실제 관측이 갱신되면 미래만 재계산하고 과거 경로/레이저 꼬리는 유지한다. 자세한 계약은 [호밍 규칙](design/combat.md#호밍-런타임--구현-완료)을 따른다. 시험은 `projectiles/homing_bullet_lab.tscn`에서 WASD로 표적을 움직이고 메뉴에서 원탄/레이저를 선택한다. 본 게임의 플레이어 호밍 무기 이식이나 피해 대상 변경은 포함하지 않는다.

## 5. BarrageVolley

소스: [barrage_volley.gd](../projectiles/barrage_volley.gd)

- `shot: BarrageShot`: 발사할 탄 설정.
- `layout = Layout.SINGLE`: 단발. `FAN`은 부채꼴, `RING`은 균등 원형.
- `count = 1`: 1~2048. SINGLE은 항상 한 발.
- `spread_degrees = 48.0`: FAN 전체 펼침각, 0~360. 1발이면 중심 방향.
- `angle_degrees = 0.0`: 배치 중심의 추가 회전각.
- `speed = 95.0`: 초기 속도.
- `origin_offset = Vector2.ZERO`: 발사자 로컬 좌표의 발사 위치 보정.
- `aim = Aim.NONE`: 조준 방식. `NONE`은 아래(0°) 기준. `EACH_SHOT`은 각 발사 시점의 표적 위치로 조준한다(발사 후 추적은 하지 않는다). `LOCKED`는 Sequence의 마지막 `aim()` 단계가 잠근 방향을 재사용한다. 발사점과 표적이 겹치면 아래 방향을 사용한다. 잠금이 없는 `LOCKED` Volley는 그 발사만 건너뛴다.
- `aimed`: 호환 별칭. 읽으면 `aim != NONE`, `true`를 쓰면 `EACH_SHOT`(이미 `LOCKED`이면 유지), `false`를 쓰면 `NONE`.
- `relative_to_emitter = false`: true면 `aim == NONE`인 방향을 발사자 `global_rotation`만큼 회전한다. 조준 Volley는 무시한다. 회전하는 적·터렛용.
- `is_valid() -> bool`.
- `directions(rotation_degrees := 0.0, aim_direction := Vector2.DOWN) -> PackedVector2Array`: 배치 방향 계산. 잘못된 설정은 빈 배열. RING은 360° 끝점을 중복하지 않는다.

## 6. BarrageSequence / BarrageStep

소스: [barrage_sequence.gd](../projectiles/barrage_sequence.gd), [barrage_step.gd](../projectiles/barrage_step.gd)

```gdscript
fire(volley: BarrageVolley)
fire_together(volleys: Array[BarrageVolley])
fire_ring(shot: BarrageShot, count: int, speed := 95.0, angle_degrees := 0.0)
fire_fan(shot: BarrageShot, count: int, spread_degrees: float,
         speed := 95.0, angle_degrees := 0.0)
wait(seconds: float)
rotate(degrees: float)
rotate_to(degrees: float)
aim()
repeat(times := 0)
build(params: Dictionary)          # 파생 패턴이 재정의
validation_error() -> String
needs_target() -> bool
```

Builder는 자기 자신을 반환한다. `fire_ring`/`fire_fan`은 기본 Volley를 만드는 편의 함수이며 조준·발사 위치 보정이 필요하면 Volley를 직접 만든다.

- `rotate(도)`는 기준각에 더하고 반복 간 누적한다. `rotate_to(도)`는 기준각을 절대값으로 설정하며 누적하지 않는다. 버스트마다 각도를 초기화하는 패턴에 사용한다.
- `aim()`은 발사자 위치→표적 방향을 잠근다. 이후 `Aim.LOCKED` Volley가 이 방향을 쓴다. 표적이 없거나 겹치면 이전 잠금을 유지한다. 잠금은 `play`마다 초기화한다. `aim()`이 있으면 조준 Volley와 같은 표적 조건을 요구한다. "한 번 조준하고 같은 방향으로 3연발"은 `aim().fire(v).wait(0.1).fire(v).wait(0.1).fire(v)`에 `v.aim = LOCKED`로 쓴다.

`fire_together`는 여러 Volley를 하나의 단계로 발사한다. 최대 64묶음·합계 4096발이며, 진행 예산이 부족하면 묶음 전체를 다음 틱으로 넘긴다. 발사가 모두 끝난 뒤 신호를 한 번 보낸다.

`repeat(n)`은 전체 Sequence 총 실행 횟수. 기본 1, 0은 무한. 마지막 wait도 수행한다. `rotate` 값은 반복 간 누적하며 새 `play` 때 초기화한다. 무한 반복에는 양수 wait가 하나 이상 필요하다. 최대 256단계, 반복 횟수 0~100000.

저장 필드는 `steps: Array[BarrageStep]`, `repeat_count`. Step은 `action`(`FIRE`, `WAIT`, `ROTATE`, `ROTATE_TO`, `AIM`), `value`(대기 초/회전 도), `volley`, `volleys`를 가진다. FIRE의 `volleys`가 비어 있지 않으면 `volley`보다 우선한다. `get_volleys()`로 실제 묶음을 조회한다.

## 7. BarragePlayer 실행 계약

소스: [barrage_player.gd](../projectiles/barrage_player.gd)

```gdscript
play(sequence: BarrageSequence, emitter: Node2D,
     projectile_parent: Node2D, target: Node2D = null) -> bool
pause()
resume()
stop()
advance(seconds: float)
```

- Player, 발사자, 탄 부모는 트리 안의 같은 Viewport에 있어야 한다. 조준(`aim != NONE` 또는 `aim()` 단계)을 사용하는 경우 표적도 같은 Viewport에 있어야 한다.
- `AIM` 단계는 `resolve_target`이 있으면 그것으로, 없으면 play의 고정 표적으로 방향을 잠근다. `may_fire`는 AIM에 적용하지 않는다. `ROTATE_TO`는 기준각을 덮어쓴다.
- 탄 부모는 발사자 자신이나 그 자식일 수 없다. 발사자가 죽어도 기존 탄이 남도록 독립된 월드 노드를 전달한다.
- `play`는 이전 재생을 먼저 중단하고 설정을 깊게 복제한다. 첫 wait 이전 발사는 즉시 실행된다. 트리 일시정지 중이면 재개 후 실행한다.
- 실패하면 false와 `last_error`. 실패한 재생 요청도 이전 재생은 중단한다.
- 물리 시간으로 자동 진행한다. `advance`는 수동 시험용으로 사용할 수 있으나 자동 진행과 중복 호출하지 않는다. 음수·비유한 시간은 무시한다.
- 한 번의 진행은 최대 256단계·4096발. 초과 시간은 다음 틱에 이어 처리한다. 따라잡기 발사는 현재 발사자·표적 위치에서 생성하며 과거 탄 위치로 소급하지 않는다.
- `pause`/`resume`은 발사 일정만 제어한다. 기존 탄까지 정지하려면 트리 일시정지를 사용한다.
- `stop`은 미래 발사를 취소한다. 기존 탄을 소거하지 않는다.
- 발사자·탄 부모·고정 모드 필수 표적의 트리 이탈은 재생을 중단한다. 같은 노드가 복귀해도 자동 재개하지 않는다. resolve_target 콜백 모드의 표적 부재는 해당 조준 발사만 건너뛴다.
- 공개 상태: `running`, `last_error`, `show_hitbox`. `running`은 pause 상태에서도 true다. `show_hitbox`는 이후 생성 탄에 적용한다.
- 신호 `volley_fired(projectiles: Array[Node2D])`: 생성된 묶음. `finished`: 자연 종료 때 한 번. stop/재생 교체에서는 발생하지 않는다.

## 8. 16방향 혼합 패턴 전체 예제

`world`와 `emitter`는 같은 Viewport의 Node2D이고 emitter는 world 아래 독립된 적 또는 발사점이라고 가정한다.

```gdscript
var balls := BarrageVolley.new()
balls.shot = preload("res://resources/projectiles/round_straight_shot.tres")
balls.layout = BarrageVolley.Layout.RING
balls.count = 8
balls.speed = 65.0

var lasers := BarrageVolley.new()
lasers.shot = preload("res://resources/projectiles/s_curve_laser_shot.tres")
lasers.layout = BarrageVolley.Layout.RING
lasers.count = 8
lasers.angle_degrees = 22.5
lasers.speed = 45.0

var sequence := BarrageSequence.new().fire_together([balls, lasers]).wait(5.0).repeat()
var runner := BarragePlayer.new()
world.add_child(runner)
if not runner.play(sequence, emitter, world):
    push_error(runner.last_error)
```

발사된 원탄은 직진하고 레이저는 각자 발사 방향을 기준으로 S자를 그린다. 저장된 동일 예제는 `resources/projectiles/mixed_sixteen_sequence.tres`다.

프리셋: `round_straight_shot.tres`, `rice_wave_shot.tres`, `crescent_laser_shot.tres`, `s_curve_laser_shot.tres`. 공유 프리셋을 수정하려면 먼저 `duplicate(true)`한다. 실제 실행은 설정을 복제하므로 원본 변경이 이미 실행 중인 탄에 소급 적용되지 않는다.

시험 진입점: [bullet_behavior_lab.tscn](../projectiles/bullet_behavior_lab.tscn). Godot에서 F6 또는 저장소 루트에서 `tools/run-godot.cmd res://projectiles/bullet_behavior_lab.tscn`.

공통 Lab의 **위협 계산 ON/OFF**로 자동 위협도 샘플링 비용을 비교할 수 있다. OFF는 실제 계산을 중단하며 다시 발사/패턴 변경에도 유지된다. 오른쪽 위의 **FPS | ms**는 최근 0.5초 구간의 화면 프레임률과 평균 프레임 간격이며 GPU 실행 시간은 아니다. pause 중에도 표시된다.

## 작성 관용구

`_init()`/`build()`는 GDScript이므로 루프로 단계를 펼칠 수 있다. Sequence는 최대 256단계, 한 단계 4096발이다. 아래는 API 추가 없이 쓰는 방식이다.

**버스트 안의 부분 반복과 버스트별 절대각** — 기존 Caster(링 20발 × 5회, 0.1초 간격, 링마다 +7°, 버스트 후 2.4초 휴식, 버스트마다 회전 초기화). 기존 Caster는 오른쪽=0°라 -90°를 더한다.

```gdscript
func build(params: Dictionary) -> void:
    var shot := preload("res://resources/projectiles/round_straight_shot.tres")
    var rings := int(params.get("rings", 5))
    for ring in rings:
        fire_ring(shot, 20, 95.0, -90.0 + ring * 7.0)   # 절대각이므로 rotate 누적 문제가 없다
        if ring < rings - 1: wait(0.1)
    wait(2.4)
    repeat()
```

`rotate()`로 누적시키고 싶다면 버스트 시작에 `rotate_to(-90)`을 두고 링마다 `rotate(7)`을 쓴다.

**다중 속도 링(속도 층)** — 같은 방향으로 속도가 다른 링을 겹친다.

```gdscript
var layers: Array[BarrageVolley] = []
for speed in [60.0, 80.0, 100.0]:
    var ring := BarrageVolley.new()
    ring.shot = shot
    ring.layout = BarrageVolley.Layout.RING
    ring.count = 16
    ring.speed = speed
    layers.append(ring)
fire_together(layers)
```

**부채꼴 안의 탄별 속도 변화** — 가운데가 빠르고 가장자리가 느린 부채꼴은 발수만큼 SINGLE Volley를 만들어 `angle_degrees`와 `speed`를 index로 보간하고 `fire_together`로 묶는다.

**조준 후 같은 방향 연발** — `aim()` + `Aim.LOCKED` (6절 참고).

**회전하는 적의 전방 발사** — `relative_to_emitter = true` (5절 참고). `use_actor_forward_direction`의 패턴 모드 대응이다.

## 9. 현재 한계

- 현재 런타임은 적 탄 전용 연결이다. Kind로 아군/적군을 선택하거나 피해량을 설정하는 API는 없다.
- 레이저는 발사점에 계속 붙어 있는 빔이 아니라 이동하는 머리의 과거 궤적이다. 제어점으로 몸통을 직접 변형하는 API는 없다.
- 발사 시점 난수(각도·속도·대기 jitter)는 없다. 필요하면 시드 RNG를 Player가 소유하는 방식으로 추가한다.
- 탄이 탄을 발사하는 분열·정지 후 재조준은 `BulletAction.Type.SPAWN`(payload Volley, 탄의 현재 위치·heading 기준 즉시 발사, 재귀 깊이 1)으로 자리를 정했고 미구현이다. 정본: [전투](design/combat.md#발사-일정behavior-표현력-확장--구현-완료).
- 중첩 Behavior 그룹, 액션 단위 반복, 외부 이벤트 대기, 외부 궤도 효과, 실행 중 Behavior 교체는 제공하지 않는다.
- 탄 노드와 물리 판정은 탄마다 존재한다. 배치 렌더링은 노드/충돌 처리 비용까지 제거하지 않는다.
- 위치·예측·레이저 과거 몸통은 같은 궤적 함수를 쓴다. 일반 이동 적분은 1/120초 중점 근사다. 직진·단일 일정 선회는 해석식, 단일 방향 파동은 직접 속도 평가를 사용한다.
- 위협 반경은 Behavior 전체의 최대 판정 배율을 사용하므로 실제 현재 판정보다 보수적일 수 있다. 성능 측정 결과와 환경은 작업 기록을 참고한다.

## 10. 본 게임 이식 — Drone·Striker·Interceptor·Caster 적용 완료

### 현재 연결 지점

[EnemyShootComponent](../components/enemy_shoot_component.gd)는 기본 조준/부채꼴 사격과 버스트를 담당한다. 화면 진입 후 활성화, 초기 지연, 활성 기간, 발사 금지선, actor 전방 발사, 표적 없음 처리, 행동 속도 배율, 위협도 보고를 함께 관리한다.

Caster도 공통 EnemyShootComponent를 사용하며 Radial 전용 컴포넌트는 제거했다. [EnemyModifierFactory](../components/enemy_modifier_factory.gd)는 공통 발사 컴포넌트에 속도 배율을 전달한다. `pattern_fire_volume_boost`는 스폰 시 발수 증강을 적용할 패턴의 명시적 opt-in이며 Drone·Striker·Interceptor만 켠다. 증강은 시작 전 컴포넌트의 독립 snapshot에 적용하고 위협도 요약을 갱신한다. 실행 중 snapshot 수정이나 자동 재시작은 지원하지 않는다.

### 1단계: 탄 생성만 연결 — 호환 경로로 유지

`EnemyShootComponent`의 선택적인 `barrage_shot: BarrageShot`은 pattern_script가 없는 호환 경로다. 설정이 있고 방향을 주입하는 발사이면 기존 fire가 계산한 월드 방향·속도로 shot.spawn을 호출하고, 그 외에는 기존 PackedScene 경로를 유지한다. Drone·Striker·Interceptor·Caster는 이제 pattern_script와 신규 BULLET 몸체를 사용한다.

이 연결로 본 게임 적이 원탄·쌀탄·S자 레이저와 Behavior를 사용할 수 있다. 현재 Drone은 패턴 모드와 새 BULLET 몸체의 needle 외형을 사용한다. `inject_target_direction = false`이며 actor 전방 발사도 꺼진 전용 씬 경로는 자동 변환하지 않는다.

직접 spawn은 즉시 add_child를 수행하므로 물리 콜백 안에서 호출하는 연결은 안전한 deferred 함수 전체로 넘긴다. 부모는 같은 Viewport의 `gameplay_world` Node2D로 정하고, 생성 전에 로컬/월드 좌표를 중복 변환하지 않는다.

### Caster의 발사 일정 — 이관 완료

`patterns/caster_pattern.gd`와 EnemyShootComponent를 사용한다. `pattern_params`의 count/rings/gap/rest/speed/spin은 적 씬에서 정한다. 초기 지연은 시작 시 한 번, 중간 링 사이에만 gap을 넣고 마지막 링 후에는 rest만 기다린다. 확정 수치는 [Caster 기획서](design/enemies/caster.md)를 따른다.

기존 Caster 링은 오른쪽=0°다. API는 아래=0°이므로 기존 모양을 보존할 때 `angle_degrees = -90 + spin_degrees`로 변환한다. 기존 링 회전은 **버스트 시작마다 0으로 초기화**된다. 전체 무한 Sequence에서 rotate를 누적하면 이 규칙이 달라지므로 각 FIRE에 절대 보정각을 넣거나 유한 버스트를 재생한다.

### 일반 적의 발사 일정 — 이관 완료

Drone은 `drone_pattern.gd`, Striker·Interceptor는 `aimed_burst_pattern.gd`를 사용한다. 공통 연발은 ways/spread/shots/gap/rest/speed를 pattern_params로 받는다. Player.may_fire가 매 FIRE의 허용 조건을 검사하므로 금지선에서 해당 발사만 건너뛴다. Interceptor는 기존 휴식까지 일정에 유지하고 활성 기간 종료로 재공격을 막아 기존 주기 기반 위협 요약을 보존한다. 기존 레거시 적은 pattern_script가 null이면 기존 Timer를 사용한다.

컴포넌트는 Player.resolve_target을 연결해 표적을 매 발사에 재조회한다. 대상이 사라져도 조준 발사만 건너뛴다. 콜백 없이 Player를 직접 사용하는 고정 표적 모드는 기존 중단 정책을 유지한다.

### 보존해야 하는 게임 연결

- 행동 속도 배율: 기존 `apply_action_rate_multiplier` 계약 유지. 패턴 모드는 Player.time_scale을 변경하며 원본 wait나 탄 이동 속도를 수정하지 않는다.
- 위협도: 기존 `get_threat_projectile_rate()` / `get_threat_reaction_time()` 유지. 패턴 모드의 계산 근사와 한계는 이 문서의 시작하기 절을 따른다.
- 수명: 적 아래의 Player는 적과 함께 제거되게 하고 탄은 독립된 월드 부모에 둔다. 전투 종료·화면 전환·일시정지·적 죽음 때 미래 발사가 멈추는지 확인한다.
- 충돌·보상: `enemy_projectiles` 그룹, Hitbox/Hurtbox, 소거당 보상, 레이저 한 몸체당 보상, 무적 시간 중 접촉 규칙을 유지한다.
- 특수 공격: Sniper의 전조/전용 configure, 화염탄, 반격탄은 각각의 계약을 검토한 뒤 별도로 옮긴다. 일반 탄 API로 일괄 대체하지 않는다.

이관한 일반 적의 Timer는 최초 활성화 지연에만 사용한다. Elite Awl은 `barrage_shot` 어댑터로 채택한 새 불꽃 몸체·꼬리를 연결하고 발사 타이밍·난수·이동은 기존 공격 제어자에 남겼다. 비교용 Legacy 구현은 제거했다.

Elite Fighter는 `elite_fighter_pattern.gd`의 유한 Sequence로 부채꼴/집중 사격을 재생한다. 제어자는 이동 정지·재개와 고정 조준 예고를 담당하고 마지막 발사의 `finished`로 다음 단계에 진입한다. ACTION_RATE는 단계별 최소 간격을 반영한 Player.time_scale로 적용한다.

Sniper는 `SniperBarrageShot`이 BarrageShot의 `is_valid()`와 `spawn()`을 재정의하는 특수 몸체 어댑터다. 폭·사거리·피해량은 Resource 설정으로 스냅샷되며 기존 SniperBullet의 Line2D 외형·판정·finished 계약을 유지한다. Appearance/Behavior/입자 꼬리는 지원하지 않는다. 탄 소멸의 finished는 Sequence의 발사 완료 신호와 별개다. 조준선·반동·재발사 일정은 SniperAttackComponent에 남는다.

`labs/enemy_attack_lab.tscn`에서 세 기체의 예고·이동·사격을 재생할 수 있다. 비사격 적의 돌진·접촉·폭발은 기존 계약을 유지한다.

반격 오그먼트는 CounterShotComponent가 `counter_wave_shot.tres`를 직접 발사한다. 피격/사망 트리거와 쿨다운은 제어자에 남기고, 파동은 BulletBehavior의 lateral_wave로 실행한다. 발사 요청은 위치·방향·설정을 복사하고 월드를 WeakRef로 보관하는 정적 지연 콜백이 처리한다. 사망 반격은 적 삭제 후에도 생성되지만 월드 삭제 시 취소된다. 일반 공격의 죽은 발사자 취소 규칙과 구별한다. Weapon Test Lab의 적 증강 목록에서 확인할 수 있으며 일반 오퍼 풀 제외는 유지한다.

### 최적화 적용 범위

위협도 격자 계산 개선은 레거시 탄에도 적용된다. MultiMesh·레이저 메쉬·판정 표시 배칭과 Behavior 계산 최적화는 새 FoundationBullet/CurvedLaser 경로에 적용된다. `Kind.LEGACY`는 기존 Sprite·파티클·컴포넌트를 사용하므로 API로 발사해도 새 배치 렌더러로 전환되지 않는다. 반대로 기존 Timer에서 새 BarrageShot을 발사하면 새 렌더링 최적화가 적용된다.
