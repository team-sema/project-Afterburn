# 오그먼트

## 기획 의도

XP를 모은 뒤 플레이어가 선택 시점을 정하며, 무기·모듈·시설로 빌드를 바꾼다. 적 증강은 다음 구간의 압력을 높인다.

카드 등급은 효과의 성격을 나눈다. 실버는 기본기(무기 획득·스탯 소폭 강화), 골드는 동작 변화, 프리즘은 규칙 파괴다. 등급은 오퍼 단위로 정해지므로 프리즘 오퍼가 뜨는 순간 자체가 이벤트가 된다.

카드 **목록·아이콘·수치** 정본:

- 플레이어 시설 → [함선 모듈](ship-modules/index.md)
- 무기 획득·특성 → [무기 모듈](weapon-modules/index.md)
- 적 증강 → 아래 「적 풀」

## Resource 모델

플레이어 증강이 비행 중 적탄의 궤도에 개입하는 공통 접점은 [전투 — 외부 궤도 개입](combat.md#외부-궤도-개입--구현-완료)을 따른다. 증강은 효과의 대상 선택·범위·수명과 탄별 핸들을 소유하고, 전투 런타임은 방향 오프셋/속도 배율 합성과 과거 보존·미래 예측 갱신을 소유한다. 적탄 조회·소거와 궤도 개입(감속·방향 오프셋) API를 쓰는 카드는 특이점(플라즈마)·정체 궤도(궤도 방벽)·시간 왜곡장·벼랑 끝이다. 원 안에 머무는 동안만 감속을 거는 장은 `BulletSlowField`(들어올 때 걸고 나갈 때 해제)를 함께 쓴다.

| 타입 | 요지 |
|------|------|
| `PlayerAugment` | `tier` · `augment_type` · `offer_weight` · 시설/무기/규칙(`rule_id`) 필드 |
| `FacilityModuleEffect` | Kind + primary/secondary/tertiary |
| `WeaponTraitDefinition` | `tier` · `max_rank`(실버 5 · 골드 3 · 프리즘 1) · `params` / `rank_overrides` |
| `EnemyAugment` | `icon` · `max_stacks` · modifiers · spawn 보너스 |
| `PlayerAugmentKind` | `FACILITY_EFFECT` · `WEAPON_ACQUIRE` · `WEAPON_TRAIT` · `SHIP_RULE` |

## 풀

`AugmentPoolLoader`가 폴더 스캔 (`auto_load_offer_pools`).

| 대상 | 경로 | 포함 |
|------|------|------|
| 플레이어 | `resources/player_augments/` | Kind 4종 · `offer_weight > 0` → **64종** (시설 10 + 획득 7 + 무기 모듈 43 + 규칙 4) |
| 적 | `resources/enemy_augments/` | `include_in_offer_pool == true` → **6종** |

- 리롤: `max_reroll_count`(임시 2) · **포커스 카드 1장만** 교체 · 포커스 카드와 같은 등급(없으면 아래 등급)에서 같은 Kind 우선
- 무기 Kind는 함선 범용 슬롯을 **쓰지 않음**

### 적 풀

| ID | 표시명 | 효과 | 아이콘 |
|----|--------|------|--------|
| `enemy_health_boost_1_2` | 적 증원 | HEALTH ×1.2 | — |
| `enemy_move_speed_boost_1_2` | 가속 적대 | MOVE_SPEED ×1.2 | — |
| `enemy_fire_volume_boost` | 포화 사격 | ACTION_RATE ×1.25 + 탄 2 · 스프레드 18° | — |
| `enemy_near_death_experience` | 임사 체험 | 치명 시 HP1 · 1초 무적 후 사망 · one-time | — |
| `enemy_drone_formation_reinforcement` | 드론 증원 편대 | Drone 편대 +1 · one-time | ![드론](enemies/sprites/enemy_drone.svg) |
| `enemy_bomb_fast_fuse` | 고속 기폭 장치 | Bomb 무장·Elite Bomb 기뢰 점멸 ÷1.5 · one-time | ![폭탄](enemies/sprites/enemy_bomb.svg) |

미등록: `enemy_counter_shot_on_hit` (`include_in_offer_pool = false`, 랩만).

반격탄은 CounterShotComponent가 피격/사망 이벤트에서 BarrageShot을 직접 발사한다. 기본 카드의 탄속 200px/s·1발·쿨다운 0.25초를 유지한다. 다발 설정은 지정한 펼침각으로 발사한다. 신규 반격탄은 반지름 4px 원형 판정과 공통 입자 꼬리를 사용하며, 발사 방향의 수직축으로 진폭 4px·주기 1초의 lateral_wave를 반복한다. 기존 화면 X축 왕복에서 발사 방향 기준 파동으로 바뀌고 발사점에서 시작한다. 수명은 8초다. 타깃이 없거나 겹치면 발사하지 않는다. 발동 순간 위치·방향·설정을 고정해 물리 콜백 밖에서 생성하며, 적이 바로 삭제되어도 요청한 반격은 남지만 월드가 제거되면 취소한다. 일반 오퍼 풀 제외는 유지한다.

포화 사격의 발수·펼침각은 Drone·Striker·Interceptor의 패턴에도 스폰 시 적용한다. 패턴의 `pattern_fire_volume_boost` 명시적 opt-in으로 연결하며 시작 전에 적용한다. Caster는 기존처럼 ACTION_RATE만 적용한다. 기존 엘리트의 발수 증가 경로는 유지한다.

`max_stacks` 0=무제한 · 1=one-time. `target_spawn_id` / `additional_spawn_count`는 Encounter 한정 보너스.

## 등급

| 등급 | 성격 | 성장 | 카드 (64) |
|------|------|------|-----------|
| 실버 | 기본기 — 무기 획득, 기본 스탯 소폭 강화. 부작용 없음 | 무기 실버 Lv.I~V 누적 | 획득 7 · 무기 실버 14 · 시설 7 |
| 골드 | 동작 — 무기·함선이 하는 일을 바꿈. 가벼운 대가 가능 | Lv.I~III | 무기 골드 22 · 시설 3 |
| 프리즘 | 규칙 — 무기 정체성·게임 규칙을 깸. 큰 대가 | 레벨 없음 | 무기 7(연쇄 분열탄 · 분광 프리즘 · 슬러그탄 · 자율 편대 · 특이점 · 표적 지정 · 정체 궤도) · 규칙 4(제4 베이 · 시간 왜곡장 · 벼랑 끝 · 공명 사격) |

- 무기 모듈 등급 배치는 [무기 모듈](weapon-modules/index.md), 시설 등급 배치는 [함선 모듈](ship-modules/index.md)이 정본이다. 무기 모듈 카드의 `tier`는 연결된 `WeaponTraitDefinition.tier`와 같다.
- **오퍼 등급**: 플레이어 오퍼를 열 때 등급을 한 번 뽑는다. 가중치는 실버 55 · 골드 40 · 프리즘 5(임시값, `AugmentOfferController` export)다. 3장 모두 그 등급의 유효 카드에서 고르고, 3장이 안 되면 한 단계 아래 등급에서 채운다(프리즘→골드→실버). 오퍼 제목(`강화 선택 · GOLD` 등)에는 실제로 나온 카드 중 가장 높은 등급을 표시한다.
- **엘리트 보상**: 엘리트 처치 1회마다 다음 플레이어 오퍼 1회의 등급 하한을 골드로 올린다(실버가 뽑히면 골드). 적립은 누적되고 플레이어 오퍼를 열 때 하나씩 쓴다.
- **프리즘 한도**: 런당 2장까지 고를 수 있다. 한도에 닿으면 프리즘 카드는 후보에서 빠지고, 프리즘이 뽑힌 오퍼는 골드로 채운다.

### 규칙 카드 (`SHIP_RULE`)

| ID | 등급 | 표시명 | 효과 | 조건 |
|----|------|--------|------|------|
| `prism_fourth_weapon_bay` | 프리즘 | 제4 베이 | 무기 베이 3→4칸 · 모든 무기 피해 ×0.85 | 베이가 3칸일 때만 |
| `prism_time_warp` | 프리즘 | 시간 왜곡장 | 함선 반경 50px 안 적탄 속도 ×0.5 · 함선 이동 속도 ×0.8 | 없음 |
| `prism_brink` | 프리즘 | 벼랑 끝 | 실드가 깨지면 화면 적탄 2초간 속도 ×0.2 · 실드 충전 속도 ×0.5 | 최대 실드 1 이상 |
| `prism_resonance_fire` | 프리즘 | 공명 사격 | 적을 처치할 때마다 무기 하나가 차례로 즉시 한 번 더 발사 · 모든 무기 연사 ×0.8 | 없음 |

규칙 카드는 범용 슬롯과 무기 베이를 쓰지 않으며, 고르면 런 끝까지 유지된다. 늘어난 베이는 빈 칸으로 추가되고, 이후 획득 오퍼는 빈 베이 기준 배율을 쓴다. 규칙 ID별 조건·적용은 `ShipRules`(`player_ship/rules/ship_rules.gd`)가 맡고, 계속 동작하는 규칙은 함선 자식 노드로 붙는다. 규칙의 시간은 게임플레이 시계를 따라 트리 일시정지 동안 멈춘다.

- **시간 왜곡장**: 함선 중심 반경 `radius` **50px** 안에 중심이 들어온 적탄은 나갈 때까지 속도 ×**0.5**(`BulletSlowField`, 핸들 `rule_time_warp`)다. 레이저 적탄은 머리 기준이다. 함선 이동 속도는 규칙 채널(`PlayerAugmentApplier.rule_move_speed_multiplier`)로 ×**0.8**. 반경은 옅은 원으로 표시한다.
- **벼랑 끝**: 실드가 1 이상에서 0이 되는 순간 발동한다. 그때 화면의 모든 적탄과 그 뒤 **2초** 안에 새로 나온 적탄에 남은 시간만큼 속도 ×**0.2**(핸들 `rule_brink`)를 건다. 발동 중 다시 깨지면 2초를 새로 센다. 실드 충전 속도는 규칙 채널(`ShieldComponent.rule_charge_speed_multiplier`)로 ×**0.5**(충전 시간 2배). 발동 동안 함선에서 청색 고리가 퍼져 나가며 옅어진다(연출 전용).
- **공명 사격**: 일반·엘리트·보스 적이 체력 0으로 쓰러질 때마다(`Enemy.DEFEAT_LISTENER_GROUP`) 장착 순서대로 돌아가며 무기 하나가 즉시 추가 발사한다(`WeaponSystem.fire_bonus_shot`). 발사형 무기는 평소 한 번의 발사를, 레이저는 피해 틱 1회를 더한다. 궤도 방벽은 차례에서 빠진다. 추가 발사는 최소 **0.1초** 간격이며 그 사이의 처치는 버린다. 모든 무기 연사는 규칙 채널(`WeaponSystem.set_rule_fire_rate_multiplier`)로 ×**0.8**. 처치한 무기를 추적하지 않으므로 차례가 처치한 무기 자신에게 돌아올 수도 있다.

## 트리거

### AugmentProgressionController

- 플레이어: XP ≥ 요구량 → HUD `AUGMENT READY [C]` · **C**로만 오픈 · 성공 시 XP 차감·레벨+1
- 첫 요구 5, 레벨마다 +3 · 레이더 `XP_GAIN_MULT` 적용
- 엘리트 처치 시 다음 플레이어 오퍼 1회의 골드 하한을 적립한다([등급](#등급)).
- 적: 시퀀스 ELITE 관문 → 엘리트 **처치·XP 정산 후** ENEMY 오퍼. 선택 완료까지 시퀀스/일반 스폰 정지. Director 미사용 시에만 60초 타이머를 쓴다. 정본: [런 페이싱](run-pacing.md).

### AugmentOfferController

- PLAYER 3장: 오퍼 등급을 정한 뒤 그 등급 안에서 `offer_weight` × 범주 배율 (획득 ×1.8 · 베이 만석 시 ×0.55 / 무기 모듈 ×1.0 / 시설 ×1.0 / 규칙 ×1.0)
- `WEAPON_ACQUIRE` 만석 → 교체 UI · 피교체 무기 성장 삭제
- `WEAPON_TRAIT` → 장착 중 무기만 · 최대 레벨(실버 V · 골드 III · 프리즘 I) 제외
- `SHIP_RULE` → 카드별 조건 충족 시만 · 선택 즉시 적용

### UI 요약

- 중앙 플레이필드 3장 캐러셀 · 포커스 미리보기는 우측 STATUS
- 시설: 빈 범용 슬롯 아이콘 점멸 · 무기: 베이/모듈 칸 점멸 · 규칙: 미리보기 없음
- 하단 `범용 슬롯 +1` 항상 표시(최대 15면 비활성) · `[R] 리롤`
- 랩: `weapon_test_lab` · C=시설 목록 · V=적 증강 전체

## 레지스트리 · 드롭

- `PlayerAugmentRegistry`: 범용 슬롯 배열 · 시설만 설치
- 무기 필드 드롭 비활성 · XP 드롭은 적별 `ExperienceDropComponent`

## 미결정 후보

- 플레이어 피격 범위 감소, 공용 관통 강화, 투사체형 무기에 호밍 추가. 기존 전용 특성과의 중첩·대상·수치는 미정이다.
- 적 파괴 후 지연 폭발, 풀에서 제외된 반격 증강 재도입. Bomb와의 역할 구분·적용 대상·보상을 먼저 정한다.
- 프리즘 후보: 과부하 베이, 스침 공명, 탄소거 환원. 태양 창(레이저 빔이 적탄 소거)은 [적탄 조회·소거](../barrage-api.md#11-적탄-조회소거--enemybullets) API로 만들 수 있다. 반사 장갑(방벽이 적탄을 되쏨)·탄막 역류는 적탄 소유권 전환 설계가 필요하다.
- 위 항목은 아이디어이며 구현 지시가 아니다.

## 완료 조건·검증

- XP만으로 오퍼가 자동 열리지 않고 C로 연다.
- 풀·장착·최대 레벨·리롤 규칙이 위와 같다.
- 한 오퍼의 카드는 뽑힌 등급으로 채워지고, 부족분만 아래 등급에서 채운다. 리롤은 등급을 유지한다.
- 엘리트 처치 뒤 첫 플레이어 오퍼는 골드 이상이다. 프리즘은 런당 2장을 넘지 않는다.
- 제4 베이를 고르면 베이가 4칸이 되고 네 번째 무기를 장착·교체할 수 있으며, 모든 무기 피해가 ×0.85가 된다.
- 시간 왜곡장을 고르면 반경 안 적탄만 느려지고 나가면 원래 속도로 돌아오며, 함선 이동 속도가 ×0.8이 된다.
- 벼랑 끝을 고르면 실드가 깨질 때 화면 적탄과 2초 안에 나온 적탄이 ×0.2로 느려졌다 풀리고, 실드 충전 시간이 2배가 된다.
- 공명 사격을 고르면 처치마다 무기가 차례로 추가 발사하고(방벽 제외, 0.1초 간격), 무기 연사가 ×0.8이 된다.
- 한 번 고른 규칙 카드는 다시 나오지 않는다.

검증 참고: `tests/augment_pool_data_driven_smoke_test.gd` · `tests/augment_offer_tier_test.gd` · `tests/fourth_weapon_bay_test.gd` · `tests/ship_rule_prism_test.gd`.
