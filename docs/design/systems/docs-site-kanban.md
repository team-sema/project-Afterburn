# Feature: docs 사이트 · 칸반 · 워크플로 이식

## 목적

Project Afterburn에 (1) Godot 프로젝트 루트 정리, (2) 카테고리 스펙 웹 + 칸반 보드, (3) cat_dice_game과 동일한 `/feature`·`/push` Cursor 룰·스킬·tools를 넣는다.

## 동작 조건

- GitHub Pages: branch `main`, folder `/docs`
- 로컬 미리보기: `docs/`에서 HTTP 서버 (file:// fetch 불가)
- `/feature`, `/push`는 `feature/*` 브랜치에서만 코드·스펙 편집

## 표시 정보

| URL (Pages) | 내용 |
|-------------|------|
| `/` | 문서 홈 |
| `/spec/` | 카테고리별 구현 스펙 브라우저 |
| `/board/` | 7열 칸반 |
| `/design/` | 설계·워크플로 링크 |

## 범위

### A. 프로젝트 루트

- `mayhem-shmup/` 내용을 리포 루트로 승격 (`project.godot`가 루트)
- 게임플레이 GDScript/씬 로직 변경 없음 (경로만)

### B. 문서 사이트

- `docs/spec/*.md` + `spec/index.html` + `spec.js`
- `docs/board/` (cat_dice 패턴: `cards.json` ↔ `cards/*.md`)
- `docs/design/` 인덱스·kanban-v2·feature-workflow

### C. 에이전트 워크플로

- `.cursor/rules/*`, `.cursor/skills/feature|push`
- `.agents/skills/afterburn-*`
- `tools/start-feature.sh`, `push-feature.sh`, `merge-feature.sh`

## 예외 조건

- Pages Settings 활성화는 저장소 관리자 작업 (코드 밖)
- `/push`만으로 칸반 `done` 금지 (`review`까지)

## 영향받는 시스템

- 저장소 레이아웃, 문서, Cursor 에이전트 규칙
- **비영향:** 오그먼트 임계, 물리 레이어, 스폰 공식, 전투 수치

## Acceptance Criteria

- [x] `project.godot`가 리포 루트에 있다
- [x] `docs/spec/`에서 카테고리별 MD를 브라우저로 열 수 있다
- [x] `docs/board/`에서 드래그·카드 MD 팝업·에이전트 프롬프트 복사가 동작한다 (JSON 다운로드 폐기)
- [x] `.cursor/skills/feature`, `push`와 `tools/*.sh`가 존재한다
- [x] 칸반 카드 `docs-site-kanban`이 이 feature와 연결된다
- [ ] GitHub Pages(`/docs`) 활성화 (팀 Settings)

## 구현 메모

- 보드 UI/CSS는 cat_dice를 Afterburn 네온 톤으로 재스킨
- `docs/spec/`은 현황 정본, `docs/design/systems/`는 feature 정본

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-28 | 보드 반영 경로: 에이전트 프롬프트 복사 (JSON 저장 폐기) |
| 2026-07-22 | 초기 스펙: 루트 승격 + docs 사이트 + 워크플로 이식 |
