# 씬 플로우

## 전이

```text
Menu (ui_accept)
  → World
       → Ship.tree_exited → 1초 대기 → Game Over
            → (ui_accept) → Menu
```

오그먼트 오버레이는 **씬 전환이 아니라** World 위 오버레이다.

## Menu (`menus/menu.tscn`)

- 타이틀 표시: **Galaxy Mayhem**
- `ui_accept` → `World` PackedScene으로 전환

## World (`world.tscn` / `world.gd`)

### 런타임 트리 (요약)

- `WorldEnvironment` — 네온 글로우
- `EnemyAugmentRegistry` / `PlayerAugmentRegistry`
- `AugmentSelectionOverlay` / `AugmentOfferController` / `ScoreAugmentOfferTrigger`
- `Ship` / `SpaceBackground` / `EnemyGenerator` / `ScoreLabel`

### 라이프사이클

1. `_ready`: `game_stats.score = 0`, 점수 라벨 연결
2. `Ship.tree_exited`: 1초 대기 후 Game Over 씬으로 이동
3. 오그먼트 오퍼 중: `get_tree().paused = true` (오버레이 `PROCESS_MODE_ALWAYS`)

## Game Over (`menus/game_over.gd`)

- `score > highscore`이면 highscore 갱신
- 점수/하이스코어 표시
- `ui_accept` → Menu

## 오그먼트 오버레이 플로우

1. `ScoreAugmentOfferTrigger`가 임계 점수 감지 → 큐
2. `AugmentOfferController.request_offer()` → `offer_started` → pause
3. 플레이어 선택 3지선다 → 즉시 `PlayerAugmentRegistry.add_augment`
4. 적 선택 3지선다 → `EnemyAugmentRegistry.add_augment` → UI 닫기
5. unpause → `offer_completed`
6. 대기 중인 오퍼가 있으면 deferred로 재요청
