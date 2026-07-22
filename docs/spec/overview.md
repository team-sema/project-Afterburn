# 개요

> **프로젝트:** Project Afterburn (`mayhem_shmup`)  
> **엔진:** Godot 4.7 · Mobile 렌더러  
> **뷰포트:** 160×240 (윈도우 오버라이드 640×960, `canvas_items` stretch)

종스크롤 슈팅에 **점수 기반 오그먼트 선택**을 얹은 프로토타입이다. 엔티티는 HeartBeast Galaxy Defiance 계열의 **컴포넌트(커스텀 노드)** 조합으로 구성한다.

## 핵심 루프

1. 적을 처치해 점수 획득
2. 점수 임계치마다 게임이 멈추고 **플레이어 오그먼트 → 적 오그먼트** 선택
3. 오그먼트는 이후 스폰/스탯에 누적 적용
4. 플레이어 사망 → 게임 오버 → 메뉴

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
project.godot / world.*
menus/          메뉴 · 게임오버 · 오그먼트 UI
player_ship/    함선 · 히트포인트 · 무기
enemies/        적 타입 · 슈팅 적
projectiles/    플레이어/적 탄
components/     재사용 커스텀 노드
resources/      GameStats · 오그먼트 Resource
effects/        배경 · 폭발 · 머티리얼 · 셰이더
assets/         PNG(레거시) + svg/(네온)
fonts/ sounds/
.agents/        비주얼 가이드
docs/           스펙 · 칸반 (본 문서)
```

## 관련 문서

- [씬 플로우](scene-flow.md)
- [컴포넌트](components.md)
- [플레이어](player.md)
- [적](enemies.md)
- [오그먼트](augments.md)
- [전투](combat.md)
- [이펙트](effects.md)
- [갭 / 확장 포인트](gaps.md)
