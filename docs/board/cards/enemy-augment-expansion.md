# 적 증강 확장

## 현황

`EnemyAugment`에는 one-time 또는 최대 중첩 설정이 없다. 적 증강 제안은 전체 풀을 매번 섞고, 선택된 증강은 동일 `augment_id`가 이미 활성화되어 있어도 `EnemyAugmentRegistry`에 다시 추가된다.

스탯 증강은 중복 횟수만큼 곱연산되고, behavior 증강은 중복 횟수만큼 컴포넌트가 생성된다.

## 목표

한 번만 등장해야 하는 적 증강과 반복 중첩 가능한 적 증강을 리소스별로 구분하고, 획득 한도에 도달한 증강을 이후 제안에서 제외한다.

## 초기 완료 조건

- [x] 적 증강 리소스에서 획득 한도를 설정할 수 있다.
- [x] 한도에 도달한 증강은 적 증강 후보에 다시 등장하지 않는다.
- [x] 기존 중첩형 증강의 동작은 명시적으로 유지한다.
- [x] 특정 적 스폰 그룹에 추가 스폰 수를 지정할 수 있다.
- [x] 적 그룹 증강 카드에 해당 적 SVG를 표시한다.
- [x] Bomb 폭발 판정·VFX·반투명 프리뷰 radius를 통일한다.
- [x] Bomb 무장 시간을 빠르게 하는 one-time 증강을 추가한다.
- [x] 후보 필터링과 중첩·스폰 정책을 자동 테스트로 검증한다.

## 구현

- `EnemyAugment.max_stacks`: `0` 무제한, `1` one-time
- `EnemyAugment.target_spawn_id` + `additional_spawn_count`: 스폰 그룹별 추가 개체 수
- `임사 체험`: one-time으로 변경
- `드론 증원 편대`: one-time, `drone_formation` +1, `enemy_drone.svg` 프리뷰
- Bomb 신관 무장 시 반투명 프리뷰 표시, 판정·최대 VFX 링과 현재 설정 기준 모두 60px
- `고속 기폭 장치`: one-time, Bomb ARMING_RATE ×1.5, `enemy_bomb.svg` 프리뷰
- 적 증강 선택 후보에서 획득 한도 도달 리소스 제외

## 예상 범위

- `resources/enemy_augments/`
- `resources/enemy_spawns/`
- `enemy_augment_registry.gd`
- `augment_offer_controller.gd`
- `enemy_generator.gd`
- `enemies/bomb_enemy.tscn`
- `components/bomb_*`
- `menus/augment_selection_overlay.gd`
- `tests/`

## 구현 이력

- 2026-08-06 `feature/enemy-augment-expansion` → main (검증 대기)
