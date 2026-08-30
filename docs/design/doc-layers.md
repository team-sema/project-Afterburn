# 기획 문서 vs 구현 스펙

문서를 쓸 때 **먼저 층만 고른다.** Notion에는 기획·스펙을 두지 않는다 (칸반만).

## 한눈에

| | **기획 문서** | **구현 스펙** |
|--|---------------|---------------|
| 질문 | *왜 / 어떤 재미·역할인가* | *지금 코드가 뭘 하는가* |
| 경로 | `docs/design/` (아래 표) | `docs/spec/` |
| TBD | 허용 | **금지** (모르면 gaps 또는 design) |
| 수치 | “목표·감”만. 확정 수치는 spec | 코드와 **1:1** |
| Pages | (기본) git에서 읽음 | `/spec/` 브라우저 |
| 독자 | 사람·기획 합의 | 검증·에이전트·머지 게이트 |

## `docs/design/` 안에서도 둘로 나눔

| 종류 | 경로 | 내용 |
|------|------|------|
| **콘텐츠 기획** | `design/enemies/`, (추후 `weapons/` 등) | 로스터 의도·역할·압박. feature slug와 무관하게 유지 |
| **방향** | `design/vision.md` | 게임 전체 재미 축·런 목표 (짧게) |
| **기능 설계** | `design/systems/<slug>.md` | *이번 feature* AC·TBD·이력. `/feature` 정본 |
| **Task** | `design/tasks/<slug>-tasks.md` | 구현 체크리스트 |
| **운영** | `kanban-v2.md` 등 | 워크플로·칸반 규칙 (기획 콘텐츠 아님) |

`systems/<slug>.md`에 “Bomb는 공간 압박” 같은 **상시 기획**을 길게 쓰지 않는다.  
로스터 의도 → `design/enemies/`. feature로 동작을 바꿀 때만 systems + **같은 커밋에** `docs/spec/` 갱신.

## `docs/spec/` — 구현 스펙만

- 확정된 동작·수치·풀·Encounter catalog·HUD에 **실제로 있는 것**
- 클래스명·씬 경로는 **구현 앵커**로만 (역할 설명이 먼저)
- 상단에 필요하면 한 줄: `기획 의도 → docs/design/enemies/…`

## 어디에 적을지 (적 예시)

| 문장 | 위치 |
|------|------|
| “Bomb는 접근을 망설이게 하는 공간 압박” | `docs/design/enemies/bomb.md` (기획) |
| “HP 160, trigger 60, 3초 점멸” | `docs/spec/enemies/bomb.md` (구현) |
| “이번 PR에서 퓨즈 3초→2.5초” | `design/systems/<slug>.md` + Task + **spec 수치 갱신** |
| “검증 대기 카드” | Notion 칸반만 |

## 금지

- Notion에 기획 본문·스펙 본문 복사
- `docs/spec/`에 TBD·“하고 싶다”
- 같은 확정 수치를 design과 spec에 **이중 정본**으로 유지 (숫자는 **spec만**)
- 식별자 나열만 하고 역할 설명이 없는 “트리”를 구현 스펙의 본문으로 쓰기

## 에이전트

- `/feature`·`/push`: 동작 변경 → **구현 스펙** 동기화 필수
- 의도만 바뀌고 코드 불변 → **기획 문서만** (spec 불필요, 응답에 명시)
- 칸반: 제목·본문 **초안 추천만** (`kanban-tickets`)

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | 초안: 기획 vs 구현 스펙 · design 하위 역할 |
