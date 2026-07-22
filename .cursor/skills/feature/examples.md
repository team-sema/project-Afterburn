# /feature 예시 — Player Augment Behaviors

## 사용자 입력

```
/feature 플레이어 오그먼트에 behavior_components가 있으면 선택 직후 Ship에 붙여서 적용한다. clear 시 제거한다.
```

## Step 1 — 스펙 요약 + slug

플레이어 오그먼트의 `behavior_components`를 `PlayerAugmentApplier`가 Ship에 인스턴스하고, `clear_augments` 시 정리한다.

- slug: `player-augment-behaviors`
- 브랜치: `feature/player-augment-behaviors`

## Step 2 — 브랜치 생성

```bash
git branch --show-current
git status --porcelain
./tools/start-feature.sh player-augment-behaviors
```

## Step 3 — 관련 문서

| 문서 | 조치 |
|------|------|
| `docs/spec/augments.md` / `player.md` / `gaps.md` | 참조 (현황) |
| `docs/design/systems/player-augment-behaviors.md` | 신규 또는 갱신 |

## Acceptance Criteria (예시)

- 오그먼트 선택 후 `behavior_components` 씬이 Ship 자식으로 붙는다.
- 동일 오그먼트를 여러 장 쌓으면 스펙에 정의한 스택 규칙을 따른다.
- `clear_augments` / 런 종료 시 behavior 인스턴스가 정리된다.
- 적 `EnemyModifierFactory` behavior 경로와 플레이어 경로를 혼동하지 않는다.
- 스탯 multiplier 적용 로직은 이 feature 스펙 범위 외로 바꾸지 않는다.

## Task 예시

`docs/design/tasks/player-augment-behaviors-tasks.md`:

```markdown
# Task: Player Augment Behaviors

## Task 1. Applier에 behavior 부착

**목적:**
- augment_added 시 behavior_components instantiate

**수정 예상 파일:**
- `components/player_augment_applier.gd`

**수정 금지:**
- `augment_offer_controller.gd` (오퍼 UI 흐름)
- 적 `enemy_modifier_factory.gd` (별도 경로)

**완료 조건:**
- 선택 후 Ship 아래에 behavior 노드가 존재한다.
```

## Audit 체크리스트

| 항목 | 확인 |
|------|------|
| `feature/player-augment-behaviors`에서 작업 | |
| 스펙 AC ↔ 구현 | |
| 칸반 카드 `doing` → `/push` 시 `review` | |
| 수정 금지 파일 미변경 | |
