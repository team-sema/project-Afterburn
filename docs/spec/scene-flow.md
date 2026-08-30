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

한 화면을 **왼쪽 HUD · 중앙 전장 · 오른쪽 STATUS** 세 칸으로 나눈다. 각 칸에 `NeonCornerFrame` 모서리 브래킷(장식)이 있다.

### 화면에 보이는 것

| 구역 | 내용 |
|------|------|
| **왼쪽** | 타이틀 → 점수 → XP·Threat 바 → 선체·실드(미충전 시 실드 게이지) → 그 아래가 전장 뷰포트 안내 |
| **중앙** | 플레이필드 `240×360` — 함선·적·탄·배경이 여기서 움직임 |
| **오른쪽 STATUS** | 위: 함선 시설(5×3 범용 육각 슬롯, 호버 시 상세) · 아래: 장착 무기·모듈 벌집(클릭/호버로 포커스, 설명은 말줄임·패널 크기 고정) |

전장 위에는 평소엔 안 보이지만, 오그먼트 선택 때 **중앙 카드 캐러셀**과(필요 시) **슬롯/베이 교체 모달**이 오버레이로 뜬다. ESC 일시정지 UI도 같은 World 위다.

### 뒤에서 도는 것 (플레이어가 이름 몰라도 됨)

| 역할 | 담당 |
|------|------|
| 점수·XP·Threat 진행 | 진행 HUD + Threat/엘리트 게이트([런·페이싱](#run-pacing)) |
| 적 스폰 | Encounter 생성기 — 무엇을 뽑을지는 [카탈로그](#encounters/catalog) |
| 플레이어/적 오그먼트 보관 | 각각의 레지스트리 (선택 결과를 런 동안 유지) |
| 오퍼 열고 닫기·일시정지 | 오퍼 컨트롤러가 요청 → 선택 UI → 레지스트리 반영 → 재개 |
| 네온 글로우 | 월드 환경(블룸) — [이펙트](#effects) |

코드/씬 노드 이름(`Ship`, `EnemyGenerator`, `AugmentOfferController` 등)은 구현·디버그용이다. **스펙을 읽을 때는 위 역할 표를 우선**하고, 상세 동작은 플레이어·오그먼트·페이싱 문서로 간다.

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
3. 플레이 시간 60초 경과 → 다음 Threat 엘리트 1기 소환. 현재 Threat는 유지하고 일반 Encounter와 다음 Threat 타이머는 정지
4. 엘리트 처치 → Threat 상승 → ENEMY 오퍼 요청. 다른 오퍼가 활성 상태면 뒤에 대기
5. `AugmentOfferController.request_offer(type)` → `offer_started(type)` → pause. 강화 분기점 인트로는 PLAYER 청색 / ENEMY 적색 테마로 구분
6. PLAYER 오퍼는 상단 3지선다와 하단 `범용 슬롯 +1`을 함께 표시. `FACILITY_EFFECT`는 우측 STATUS 범용 육각 슬롯의 같은 tag·빈 칸 미리보기, 무기 Kind는 병기 배치·모듈 레벨 미리보기를 표시하되 하단 슬롯 확장 버튼은 바꾸지 않음
7. 시설 카드 → 범용 빈 슬롯 설치(가득 차면 전체 슬롯 교체 모달). 무기 Kind(획득·모듈 강화) → 로드아웃에 직접 적용(만석 획득은 베이 교체 UI). `범용 슬롯 +1`은 Kind와 무관하게 선택 가능(포커스/호버 → 다음 육각 칸 점멸, 선택 → 용량 +1; 시작 5, 최대 15면 비활성)
8. ENEMY 오퍼는 기존 3지선다 선택 → registry 반영
9. **PLAYER 오퍼 종료 직후** 함선 주변 `enemy_projectiles` 제거 + `augment_resume_burst` VFX (`player_resume_clear_radius` 기본 36)
10. unpause → `offer_completed(type)`. ENEMY 오퍼였다면 일반 Encounter와 새 60초 타이머 재개
11. 대기 중인 오퍼가 있으면 deferred로 재요청

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | World「런타임 트리」식별자 나열 → 화면 구역·역할 표로 교체 |