# 씬 플로우

## 전이

```text
Menu (ui_accept)
  → World
       → Ship.tree_exited → 1초 대기 → Game Over
            → (ui_accept) → Menu
```

오그먼트 오버레이는 **씬 전환이 아니라** World 위 오버레이다. 오퍼 중 전투는 일시정지하지만 전장과 좌우 HUD는 계속 보이며, 중앙 카드 캐러셀과 우측 STATUS 미리보기를 함께 사용한다.

## Menu (`menus/menu.tscn`)

- 타이틀 표시: **Galaxy Mayhem**
- `ui_accept` → `World` PackedScene으로 전환

## World (`world.tscn` / `world.gd`)

### 런타임 트리 (요약)

- `WorldEnvironment` — 네온 글로우
- `EnemyAugmentRegistry` / `PlayerAugmentRegistry`
- `AugmentSelectionOverlay` / `AugmentModuleSwapOverlay` / `AugmentOfferController` / `AugmentProgressionController`
- `Ship` / `SpaceBackground` / `EnemyGenerator` / `ScoreLabel`

우측 패널(`world.tscn`): `STATUS` → `ShipPanel`(5×3 범용 육각 슬롯 벌집 + 슬롯 호버 상세) → `WeaponBox/Margin/WeaponLoadoutHud`

`WeaponLoadoutHud`: 템플릿 복제 48px 무기 베이·28px 장착 모듈 flat-top 헥스를 변이 맞닿는 벌집으로 배치 → 좌우(`선택된 무기` | `장착된 모듈`) → 가로선+고정 2줄 설명. 호버/클릭 포커스. 설명 초과분은 말줄임하며 우측 레일 크기를 변경하지 않는다.

좌측 패널(`world.tscn`): 타이틀 → `SCORE` → `ProgressionHud`(XP·위협 바) → `ShipStatusHud`(선체·실드 바 · 실드 미만 시 `ShieldChargeBar`) → `PLAYFIELD`(`240 × 360`)

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
3. 플레이 시간 30초마다 ENEMY 오퍼를 큐에 추가 (도달 순으로 처리)
4. `AugmentOfferController.request_offer(type)` → `offer_started(type)` → pause. 강화 분기점 인트로는 PLAYER 청색 / ENEMY 적색 테마로 구분
5. PLAYER 오퍼는 상단 3지선다와 하단 `범용 슬롯 +1`을 함께 표시. `FACILITY_EFFECT`는 우측 STATUS 범용 육각 슬롯의 같은 tag·빈 칸 미리보기, 무기 Kind는 병기 배치·모듈 레벨 미리보기를 표시하되 하단 슬롯 확장 버튼은 바꾸지 않음
6. 시설 카드 → 범용 빈 슬롯 설치(가득 차면 전체 슬롯 교체 모달). 무기 Kind(획득·모듈 강화) → 로드아웃에 직접 적용(만석 획득은 베이 교체 UI). `범용 슬롯 +1`은 Kind와 무관하게 선택 가능(포커스/호버 → 다음 육각 칸 점멸, 선택 → 용량 +1; 시작 5, 최대 15면 비활성)
7. ENEMY 오퍼는 기존 3지선다 선택 → registry 반영
8. **PLAYER 오퍼 종료 직후** 함선 주변 `enemy_projectiles` 제거 + `augment_resume_burst` VFX (`player_resume_clear_radius` 기본 36)
9. unpause → `offer_completed(type)`
10. 대기 중인 오퍼가 있으면 deferred로 재요청
