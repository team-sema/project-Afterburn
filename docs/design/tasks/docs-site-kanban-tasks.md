# Task: docs 사이트 · 칸반 · 워크플로 이식

## Task 1. Godot 루트 승격

**목적:**
- `mayhem-shmup/` 내용을 리포 루트로 이동

**수정 예상 파일:**
- 리포 루트 전체 (rename only)
- `project.godot` 위치

**수정 금지:**
- 게임 로직·오그먼트 수치·물리 레이어 의미 변경

**완료 조건:**
- [x] 루트에 `project.godot` 존재, `mayhem-shmup/` 제거

---

## Task 2. 스펙·칸반·설계 문서 사이트

**목적:**
- 카테고리 스펙 브라우저 + 7열 칸반 + design 인덱스

**수정 예상 파일:**
- `docs/**`

**수정 금지:**
- `components/`, `player_ship/`, `enemies/` 등 게임플레이 코드

**완료 조건:**
- [x] `docs/index.html`, `docs/spec/`, `docs/board/`, `docs/design/` 존재

---

## Task 3. Cursor 룰·스킬·tools 이식

**목적:**
- cat_dice `/feature`·`/push` 워크플로를 Afterburn에 맞게 반영

**수정 예상 파일:**
- `.cursor/**`
- `.agents/skills/afterburn-*`
- `tools/*.sh`

**수정 금지:**
- 게임플레이 GDScript 동작 변경

**완료 조건:**
- [x] feature/push 스킬, 7 rules, tools 스크립트 존재

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-22 | Task 문서 추가 |
