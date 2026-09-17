# 씬 플로우

## 기획 의도

중앙 전장을 유지하면서 좌우 HUD로 상태를 읽고, 선택 중에는 전투를 멈춰 판단 시간을 제공한다.

## 확정된 현재 동작

개발 시험의 공통 입구는 `labs/lab_hub.tscn`이다. 탄막·패턴, 무기·증강, 실제 전투 위협도, 증강 카드 UI를 목록에서 방향키/Enter로 선택한다. 허브에서 연 Lab은 F1로 목록에 복귀하며, 씬은 하나씩 실행한다. 기존 개별 씬의 F6 실행도 유지한다. 본 게임 시작 씬은 변경하지 않는다. 탄막 스크립트 작업 규칙은 [전투](combat.md)를 따른다.

## 전이

```text
Menu (ui_accept)
  → World
       → Ship.tree_exited → 1초 대기 → Game Over
            → (ui_accept) → Menu
```

오그먼트 오버레이는 **씬 전환이 아니라** World 위 오버레이다. 오퍼 중 전투는 일시정지하지만 전장과 좌우 HUD는 계속 보이며, 중앙 카드 캐러셀과 우측 STATUS 미리보기를 함께 사용한다.

## Menu (`menus/menu.tscn`)

- 타이틀 표시: **갤럭시 메이헴**
- 메뉴 진입 시 World를 비동기로 미리 로드한다. `ui_accept`로 시작을 요청하고 로딩이 끝나면 전환하며, 대기 중 준비 상태·진행률을 표시한다.

## World (`world.tscn` / `world.gd`)

한 화면을 **왼쪽 HUD · 중앙 전장 · 오른쪽 STATUS** 세 칸으로 나눈다. 각 칸에 `NeonCornerFrame` 모서리 브래킷(장식)이 있다.

### 화면에 보이는 것

| 구역 | 내용 |
|------|------|
| **왼쪽** | 타이틀 → 점수 → XP·STAGE 진행 바 → 선체·실드(미충전 시 실드 게이지) → 그 아래가 전장 뷰포트 안내 |
| **중앙** | 플레이필드 `240×360` — 함선·적·탄·배경이 여기서 움직임 |
| **오른쪽 STATUS** | 위: 함선 시설(5×3 범용 육각 슬롯, 호버 시 상세) · 아래: 장착 무기·모듈 벌집(클릭/호버로 포커스, 설명은 말줄임·패널 크기 고정) |

전장 위에는 평소엔 안 보이지만, 오그먼트 선택 때 **중앙 카드 캐러셀**과(필요 시) **슬롯/베이 교체 모달**이 오버레이로 뜬다. ESC 일시정지 UI도 같은 World 위다.

### 뒤에서 도는 것 (플레이어가 이름 몰라도 됨)

| 역할 | 담당 |
|------|------|
| 점수·XP·Threat 진행 | 진행 HUD + Threat/엘리트 게이트([런·페이싱](run-pacing.md)) |
| 적 스폰 | Encounter 생성기 — 무엇을 뽑을지는 [카탈로그](encounters/catalog.md) |
| 플레이어/적 오그먼트 보관 | 각각의 레지스트리 (선택 결과를 런 동안 유지) |
| 오퍼 열고 닫기·일시정지 | 오퍼 컨트롤러가 요청 → 선택 UI → 레지스트리 반영 → 재개 |
| 네온 글로우 | 월드 환경(블룸) — [이펙트](effects.md) |

코드/씬 노드 이름(`Ship`, `EnemyGenerator`, `AugmentOfferController` 등)은 구현·디버그용이다. **기획서를 읽을 때는 위 역할 표를 우선**하고, 상세 동작은 플레이어·오그먼트·페이싱 문서로 간다.

### 마스터 볼륨

World 왼쪽 패널에 MasterVolumeControl을 표시한다. 슬라이더는 Master 버스에 즉시 적용되고 0이면 음소거한다. user://settings.cfg에 저장하며 일시정지 중에도 조절할 수 있다.

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
3. 시퀀스 ELITE 스텝 → 다음 Threat 엘리트 1기 소환. 현재 Threat는 유지하고 일반 Encounter와 시퀀스는 대기한다. Director 미사용 시에만 60초 타이머로 요청한다.
4. 엘리트 처치 → 즉시 pause → 모든 `enemy_projectiles`를 탄 위치의 XP 1 오브로 변환. 기존 XP와 엘리트 확정 드롭도 함께 플레이어에게 강제 흡수하며 이 동안 `C` 플레이어 오퍼 입력을 잠금
5. 모든 XP의 실제 정산 완료 → Threat 상승 → ENEMY 오퍼 요청. pause 소유권을 오퍼에 그대로 인계
6. `AugmentOfferController.request_offer(type)` → `offer_started(type)` → pause. 강화 분기점 인트로는 PLAYER 청색 / ENEMY 적색 테마로 구분
7. PLAYER 오퍼는 상단 3지선다와 하단 `범용 슬롯 +1`을 함께 표시. `FACILITY_EFFECT`는 우측 STATUS 범용 육각 슬롯의 같은 tag·빈 칸 미리보기, 무기 Kind는 병기 배치·모듈 레벨 미리보기를 표시하되 하단 슬롯 확장 버튼은 바꾸지 않음
8. 시설 카드 → 범용 빈 슬롯 설치(가득 차면 전체 슬롯 교체 모달). 무기 Kind(획득·모듈 강화) → 로드아웃에 직접 적용(만석 획득은 베이 교체 UI). `범용 슬롯 +1`은 Kind와 무관하게 선택 가능(포커스/호버 → 다음 육각 칸 점멸, 선택 → 용량 +1; 시작 5, 최대 15면 비활성)
9. ENEMY 오퍼는 기존 3지선다 선택 → registry 반영
10. **PLAYER 오퍼 종료 직후** 함선 주변 `enemy_projectiles` 제거 + `augment_resume_burst` VFX (`player_resume_clear_radius` 기본 36)
11. unpause → `offer_completed(type)`. ENEMY 오퍼였다면 게이트를 닫고 시퀀스 진행 재개 (Director 미사용 시에만 일반 스폰·새 60초 타이머 재개)
12. 대기 중인 오퍼가 있으면 deferred로 재요청

---


## 위협도 모니터 장면

`threat_monitor/threat_monitor_lab.tscn`을 에디터에서 열고 **F6**으로 실행한다. 화면 중앙은 본 게임과 같은 240×360 플레이 영역이며, 왼쪽에는 현재값·완화값·최근 최고값·누적량과 실시간 그래프, 오른쪽에는 다섯 구성 값·동시 공격원·공격 종류·표본 개수가 표시된다. 좌우 패널·플레이필드 합쳐 **640×360 뷰포트 안에 들어가** 위아래가 잘리지 않아야 한다. 함선은 계측 도중 파괴되지 않으며, **R** 또는 다시 시작 버튼으로 장면을 초기화할 수 있다.

세부 계산식과 기준값은 [전투](combat.md)의 「개발용 실시간 위협도 계측」을 따른다.

## 완료 조건·검증

- 메뉴→플레이→게임 오버→메뉴 흐름이 완료된다.
- 다른 시스템이 소유한 일시정지를 ESC로 해제할 수 없다.
- 방향 입력과 확인만으로 선택·교체를 완료하고 모달 복귀 시 유효 포커스를 복원한다.

검증 참고: `tests/pause_smoke_test.gd`. Godot 실행은 `tools/run-godot.cmd`를 사용한다.
