# Project Afterburn

Godot 4.7 종스크롤 슈팅 + XP·시간 기반 오그먼트 프로토타입 (`mayhem_shmup`).

적을 처치해 XP를 모으고 **`C`** 로 플레이어 오그먼트(시설 모듈 · 무기 획득/레벨/특성)를 고른다. 약 30초마다 적 오그먼트도 선택된다.

## 문서

| | URL |
|--|-----|
| 문서 홈 | https://team-sema.github.io/project-Afterburn/ |
| **스펙** (카테고리별) | https://team-sema.github.io/project-Afterburn/spec/ |
| **칸반 보드** | https://team-sema.github.io/project-Afterburn/board/ |

로컬 미리보기:

```bash
cd docs
# HTTP 서버로 연 뒤
# http://localhost:8080/spec/
# http://localhost:8080/board/
```

원본 MD: [`docs/spec/`](docs/spec/) · [`docs/board/`](docs/board/)

## 실행

1. Godot **4.7** stable로 이 저장소 루트(`project.godot`)를 연다.
2. `F5` 또는 메인 씬(`menus/menu.tscn`) 실행.

## 워크플로

- `/feature` → 스펙·Task → 구현 → `/push` (main merge)
- 상세: [`docs/design/feature-workflow.md`](docs/design/feature-workflow.md)
