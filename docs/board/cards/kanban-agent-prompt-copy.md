# 칸반 에이전트 프롬프트 복사

보드에서 드래그한 열 변경을 Cursor 프롬프트로 복사해 저장소에 반영한다. JSON 복사/다운로드는 제거.

## 목표

- [x] JSON 복사·cards.json 저장 버튼 제거
- [x] 저장소 대비 열 diff → 에이전트 프롬프트 복사
- [x] 보드 hint·README·kanban-v2·룰 가이드 갱신

## AC

- [x] 변경 없으면 토스트로 안내
- [x] 변경 있으면 id·from→to 목록이 클립보드에 들어감
- [x] 문서에 “붙여넣기 → 에이전트 반영” 경로 명시

## 구현

- 2026-07-28 feature/kanban-agent-prompt-copy
- 2026-07-28 feature/kanban-agent-prompt-copy → main (검증 대기)
