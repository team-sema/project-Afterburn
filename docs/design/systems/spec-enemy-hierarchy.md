# Feature: 적·진형·Encounter 스펙 계층 + Pages 가시성

## 목적

`enemies.md`에 섞여 있던 **유닛 / 진형 / 조합 / 페이싱**을 구현 스펙으로 분리하고,  
**기획(의도)** 은 `docs/design/enemies/` · 층 규칙은 `doc-layers.md`로 구분한다. Pages에서 계층 탐색.

## 동작 조건

- 구현 정본: `docs/spec/enemies|formations|encounters|run-pacing`
- 기획: `docs/design/enemies/`, `vision.md`, `doc-layers.md`
- Pages: 그룹 네비 · 층 칩 · `#enemies/drone` 해시
- 게임 코드 미변경

## Acceptance Criteria

- [x] 적·진형·Encounter·run-pacing 계층 MD
- [x] Pages 그룹 네비·칩·브레드크럼
- [x] 기획 vs 구현 스펙 문서·규칙 반영
- [x] `design/enemies` 로스터 의도 표

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | doc-layers · vision · design/enemies · 규칙 동기화 |
| 2026-08-30 | 초안 · 구현 스펙 계층 |
