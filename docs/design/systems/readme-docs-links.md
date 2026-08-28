# Feature: README에 스펙·칸반 링크

## 목적

저장소 루트 `README.md`에서 GitHub Pages 스펙 브라우저·칸반 보드로 바로 갈 수 있게 한다.

## 동작 조건

- Pages가 `main` / `/docs`로 배포된 경우 링크가 유효하다.
- Pages 미설정 시에도 README에 URL·로컬 미리보기 안내가 있다.

## 표시 정보

| 링크 | URL |
|------|-----|
| 문서 홈 | https://team-sema.github.io/project-Afterburn/ |
| 스펙 | https://team-sema.github.io/project-Afterburn/spec/ |
| 칸반 (Notion) | https://app.notion.com/p/102c71bf78394bcaa9ff627548faf7f9?v=3c9b8c11155f8111bfeb000c00cae3b8 |

## 예외 조건

- Pages Settings 활성화는 이 feature 범위 밖.

## 영향받는 시스템

- `README.md`만. 게임 코드·칸반 카드 본문 구조 변경 없음 (티켓 열 이동만).

## Acceptance Criteria

- [x] 루트 `README.md`가 있다
- [x] 스펙·칸반 Pages URL이 표 또는 동등한 형태로 있다
- [x] `docs/spec/` 상대 경로 안내가 있다

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-29 | Pages `/board/` 제거; README·링크는 Notion 칸반 |
| 2026-07-22 | 초기 스펙 |
