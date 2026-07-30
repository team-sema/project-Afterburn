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
- `AugmentSelectionOverlay` / `AugmentOfferController` / `AugmentProgressionController`
- `Ship` / `SpaceBackground` / `EnemyGenerator` / `ScoreLabel`

### 라이프사이클

1. `_ready`: `game_stats.score = 0`, 점수 라벨 연결
2. `Ship.tree_exited`: 1초 대기 후 Game Over 씬으로 이동
3. 오그먼트 오퍼 중: `get_tree().paused = true` (오버레이 `PROCESS_MODE_ALWAYS`)
4. **ESC** (`world_shell.gd`): 수동 일시정지 토글 · `PauseOverlay` 표시. 오그먼트 등 **다른 시스템이 건 pause** 중에는 ESC로 해제하지 않음

## Game Over (`menus/game_over.gd`)

- `score > highscore`이면 highscore 갱신
- 점수/하이스코어 표시
- `ui_accept` → Menu

## 오그먼트 오버레이 플로우

1. 적 사망 시 경험치 오브 드롭 → 플레이어 접촉 시 경험치 획득
2. XP가 요구량을 채워도 **자동으로 열리지 않음**. `open_augment_offer`(**C**)로 PLAYER 오퍼 요청 · 오퍼 UI가 이미 열려 있으면 XP 미소모
3. 플레이 시간 60초마다 ENEMY 오퍼를 큐에 추가 (도달 순으로 처리)
4. `AugmentOfferController.request_offer(type)` → `offer_started(type)` → pause
5. 해당 타입의 3지선다 선택 → registry 반영 → UI 닫기
6. **PLAYER 오퍼 종료 직후** 함선 주변 `enemy_projectiles` 제거 + `augment_resume_burst` VFX (`player_resume_clear_radius` 기본 36)
7. unpause → `offer_completed(type)`
8. 대기 중인 오퍼가 있으면 deferred로 재요청
