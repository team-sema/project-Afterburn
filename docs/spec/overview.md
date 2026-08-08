# 개요

> **프로젝트:** Project Afterburn (`mayhem_shmup`)  
> **엔진:** Godot 4.7 · Mobile 렌더러  
> **뷰포트:** 640×360 셸 (윈도우 오버라이드 1280×720, `canvas_items` stretch) · 플레이필드 SubViewport는 240×360 중앙 레일

종스크롤 슈팅에 **XP·시간 기반 오그먼트 선택**을 얹은 프로토타입이다. 엔티티는 HeartBeast Galaxy Defiance 계열의 **컴포넌트(커스텀 노드)** 조합으로 구성한다.

## 핵심 루프

1. 적을 처치해 점수·XP 획득
2. XP 충족 후 **C**로 플레이어 오그먼트 선택 · 약 30초마다 적 오그먼트 선택 (일시정지)
3. 플레이어 오퍼: 시설 모듈(13종)·슬롯 확장, 또는 무기 획득·전용 모듈(Lv.I~III)
4. 장착 무기는 통합 베이에서 **동시 사격**. 무기 필드 드롭 없음
5. 플레이어 사망 → 게임 오버 → 메뉴

## 메인 씬

| 역할 | 경로 | 비고 |
|------|------|------|
| 메인(메뉴) | `menus/menu.tscn` | `project.godot` run/main_scene |
| 플레이 | `world.tscn` | 게임플레이 루트 |
| 게임 오버 | `menus/game_over.tscn` | 함선 `tree_exited` 후 진입 |

## Autoload

| 이름 | 내용 |
|------|------|
| `ResourceStash` | `GameStats` (`game_stats.tres`) 홀더 |
| `MusicPlayer` | BGM (`sounds/music.ogg`, bus `Music`) |

레지스트리·오퍼 컨트롤러는 Autoload가 아니라 **World 자식**이다.

## 폴더 맵

```text
project.godot
world.tscn / world.gd / world_shell.gd      플레이 셸 · 일시정지
gameplay.tscn                               런 조립 (함선 · 생성기 · 레지스트리 · 오퍼 풀)
augment_*_controller.gd / *_augment_registry.gd / enemy_generator.gd
menus/          메뉴 · 게임오버 · 오그먼트 UI · STATUS
player_ship/    함선 · 히트포인트 · 통합 무기 로드아웃 (weapons/)
enemies/        적 타입 · 슈팅 적
projectiles/    플레이어/적 탄
pickups/        XP 오브 · 무기 픽업
components/     재사용 커스텀 노드 (augment_behaviors/)
resources/      GameStats · 오그먼트 · 무기 · 시설 Resource
effects/        배경 · 폭발 · 머티리얼 · 셰이더
weapon_test/    무기 테스트장
tests/          headless 스모크 테스트
assets/         PNG(레거시) + svg/(네온)
fonts/ sounds/
.agents/        비주얼 가이드 · 스킬
tools/          run-godot.cmd · feature 스크립트
docs/           스펙 · 칸반 · 설계 (본 문서)
```

루트에 `gameplay.tscn`·오퍼/진행 컨트롤러·레지스트리가 함께 있다. 하위 폴더로 옮기는 정리는 백로그 (`docs/spec/gaps.md`).

## 스펙 페이지 트래킹

Pages 스펙 브라우저(`docs/spec/index.html` · `spec.js`의 `CATEGORIES`)가 아래 MD를 전부 로드한다.  
**목록·수치·동작의 정본은 이 카테고리 MD**이며, `docs/design/systems/`는 feature 설계·이력이다.

| 카테고리 | 파일 | 트래킹 내용 |
|----------|------|-------------|
| 개요 | `overview.md` | 루프 · 씬 · Autoload · 폴더 |
| 씬 플로우 | `scene-flow.md` | 메뉴·World·오퍼·STATUS 패널 |
| 컴포넌트 | `components.md` | 재사용 커스텀 노드 · 시설 버프/부스터 |
| 플레이어 | `player.md` | 함선 · 무기 7종·기본 수치 · **시설 13모듈** · 실드 버퍼/재생 · HUD |
| 적 | `enemies.md` | 타입 · 생성기 · Threat · `is_boss` |
| 오그먼트 | `augments.md` | **플레이어 48·적 6 풀** · 시설 13 · 무기 모듈 28 · Kind · 리롤 |
| 전투 | `combat.md` | 레이어 · 탄 · 플레이어 피격=1 · 실드 버퍼 |
| 이펙트 | `effects.md` | 네온 · 배경 · 폭발 |
| 갭 | `gaps.md` | 미연결 · 백로그 후보 |
