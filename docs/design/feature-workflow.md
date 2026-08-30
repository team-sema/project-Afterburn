# Feature 워크플로 요약

상세: `.cursor/skills/feature/SKILL.md`, `.cursor/skills/push/SKILL.md`

## 문서 위치

| 내용 | 경로 |
|------|------|
| 의도·역할·방향 (기획) | `docs/design/vision.md`, `docs/design/enemies/` … · Pages `/design/` |
| 이번 feature AC | `docs/design/systems/<slug>.md` |
| Task | `docs/design/tasks/<slug>-tasks.md` |
| 지금 코드 동작·수치 | `docs/spec/` · Pages `/spec/` |
| 칸반 티켓·열 | Notion만 |

확정 수치는 spec만. 동작이 바뀌면 같은 커밋에 spec을 맞춘다.

## `/feature <설명>`

1. slug → `./tools/start-feature.sh <slug>`
2. Notion 카드 **제목·본문 초안만** 추천 (생성·열은 사람)
3. 의도 변경 → 기획 MD · AC → `systems/<slug>.md` · Task
4. 구현 · **동작 변경 시 `docs/spec/` 같이**
5. Audit → `/push`

## `/push`

1. systems·Task·spec·diff 정합성
2. 칸반 제목·본문 초안만
3. `./tools/push-feature.sh -m "…"`
4. `origin/main` 신규면 중단 → feature에서 `git merge main` 후 재시도

## 스크립트

| 스크립트 | 역할 |
|----------|------|
| `tools/start-feature.sh` | `feature/<slug>` 생성 |
| `tools/push-feature.sh` | 커밋 + merge |
| `tools/merge-feature.sh` | 이미 커밋된 feature merge |

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | doc-layers 흡수 · 메타 문구 축소 |
| 2026-08-29 | Pages `/board/` 제거; 제목·본문만 추천 |
| 2026-08-28 | 칸반 초안 추천 |
| 2026-07-22 | Afterburn 워크플로 요약 |
