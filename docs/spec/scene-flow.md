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
- `AugmentSelectionOverlay` / `AugmentModuleSwapOverlay` / `AugmentOfferController` / `AugmentProgressionController`
- `Ship` / `SpaceBackground` / `EnemyGenerator` / `ScoreLabel`

우측 패널(`world.tscn`): `STATUS` → `ShipPanel`(함선 그림 + 시설 칩 6종 + `시설명 : 슬롯` 한 줄) → `WeaponBox/Margin/WeaponLoadoutHud`

`WeaponLoadoutHud`: **무기 모듈** → 장착 베이(동일 크기 헥스 가로 나열, 클릭 포커스) → **좌우 2열**(`선택된 무기` | `장착된 모듈` 2×2). 탄약·주/보조 구분 없음.

좌측 패널(`world.tscn`): 타이틀 → `SCORE` → `ProgressionHud`(XP·위협 바) → `ShipStatusHud`(선체·실드 바) → `PLAYFIELD`

좌·플레이필드·우 세 패널에 `NeonCornerFrame` 모서리 브래킷 (장식 전용).

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
5. PLAYER 오퍼는 상단 3지선다와 하단 함선 UI를 함께 표시하고, 카드 포커스가 대상 부위를 하이라이트
6. PLAYER 카드 선택 → 빈 슬롯 설치. 가득 찬 부위는 교체 모달 표시. 함선 부위 선택 → 슬롯 용량 +1(최대 3)
7. ENEMY 오퍼는 기존 3지선다 선택 → registry 반영
8. **PLAYER 오퍼 종료 직후** 함선 주변 `enemy_projectiles` 제거 + `augment_resume_burst` VFX (`player_resume_clear_radius` 기본 36)
9. unpause → `offer_completed(type)`
10. 대기 중인 오퍼가 있으면 deferred로 재요청
