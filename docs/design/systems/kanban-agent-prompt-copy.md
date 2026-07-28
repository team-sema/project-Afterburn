# 칸반 에이전트 프롬프트 복사

> 보드 UI에서 열 변경 → Cursor 프롬프트로 저장소 반영.

## 범위

- `docs/board/index.html`, `board.js`
- `docs/board/README.md`, `docs/design/systems/kanban-v2.md`
- `.cursor/rules/kanban-tickets.mdc`
- (참고) `docs/submission/04-ai-usage.md` 칸반 절

## Acceptance

- [x] JSON 복사·다운로드 버튼 없음
- [x] **에이전트 프롬프트 복사**: 저장소 대비 `column` diff만 프롬프트로 생성
- [x] hint·README·룰에 반영 경로 문서화
- [x] 변경 0건이면 복사하지 않고 안내

## 비범위

- GitHub API로 보드에서 직접 커밋
- cat_dice_game 원본 저장소 변경

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-28 | 초안·구현 |
