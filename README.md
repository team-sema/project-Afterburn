# Project Afterburn

Godot 4.7 종스크롤 슈팅 + XP·시간 기반 오그먼트 프로토타입 (`mayhem_shmup`).

적을 처치해 XP를 모으고 **`C`** 로 플레이어 오그먼트(시설 모듈 · 무기 획득/레벨/특성)를 고른다. 등장 시퀀스의 엘리트 관문을 처치하고 XP를 정산하면 Threat가 상승하고 적 오그먼트를 선택한다.

## 문서

| | URL |
|--|-----|
| 문서 홈 | https://team-sema.github.io/project-Afterburn/ |
| **기획서** (의도·규칙·수치) | https://team-sema.github.io/project-Afterburn/design/ |
| **칸반 (Notion)** | https://app.notion.com/p/102c71bf78394bcaa9ff627548faf7f9?v=3c9b8c11155f8111bfeb000c00cae3b8 |

로컬 미리보기:

```bash
cd docs
# HTTP 서버로 연 뒤
# http://localhost:8080/design/
```

원본 MD: [`docs/design/`](docs/design/README.md)

## 실행

1. Godot **4.7** stable로 이 저장소 루트(`project.godot`)를 연다.
2. `F5` 또는 메인 씬(`menus/menu.tscn`) 실행.

## 개발 Lab

**[`labs/lab_hub.tscn`](labs/lab_hub.tscn)을 열고 F6**으로 시험 환경을 선택한다. 탄막·패턴, 무기·증강, 실제 전투 위협도, 증강 카드 UI를 한곳에서 열며 **F1**로 목록에 돌아온다.

패턴 작성은 **탄막 · 패턴 스크립트**에서:

1. [`patterns/lab_example_pattern.gd`](patterns/lab_example_pattern.gd)를 복사해 `BarrageSequence` 패턴을 작성한다.
2. 화면 왼쪽 위 **스크립트 열기**에서 파일과 발사 위치를 선택하고 실행한다.
3. 에디터에서 수정·저장한 뒤 **실행 창에서 F5**로 다시 읽는다. WASD 표적 이동, 위협 계산 ON/OFF, FPS, 판정 표시를 함께 사용한다.

직접 실행: `tools/run-godot.cmd res://projectiles/bullet_lab.tscn -- --pattern=res://patterns/lab_example_pattern.gd`

기존 `projectiles/*_lab.tscn`은 같은 탄막 Lab의 예제별 바로가기다. [패턴 작성 API](docs/barrage-api.md) · [현재 규칙](docs/design/combat.md)

## 워크플로

- `/feature` → 기획서·Task → 구현 → `/push` (main merge)
- 상세: [`docs/design/feature-workflow.md`](docs/design/feature-workflow.md)
