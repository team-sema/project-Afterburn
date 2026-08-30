# Feature 워크플로 요약

상세 정본: `.cursor/skills/feature/SKILL.md`, `.cursor/skills/push/SKILL.md`  
문서 층: [`doc-layers.md`](doc-layers.md) (기획 vs 구현 스펙)

## `/feature <설명>`

1. slug 추론 → `./tools/start-feature.sh <slug>`
2. Notion 카드 **제목·본문 초안만 추천** (생성·열 이동은 사람)
3. 의도·역할이 바뀌면 `docs/design/` 기획 문서 · feature AC는 `systems/<slug>.md`
4. `docs/design/tasks/<slug>-tasks.md` Task 분리
5. 스펙 범위 안만 구현 · **동작 변경 시 `docs/spec/` 같이**
6. Audit → 사용자 확인 후 `/push`

## `/push`

1. 기획/systems·Task·**구현 스펙**·diff 정합성
2. Notion 카드 **제목·본문 초안만 추천**
3. `./tools/push-feature.sh -m "feat: ..."`
4. `origin/main` 신규면 **중단**(exit 2) → feature에서 `git merge main` 후 재시도

## 스크립트

| 스크립트 | 역할 |
|----------|------|
| `tools/start-feature.sh` | main에서 `feature/<slug>` 생성 |
| `tools/push-feature.sh` | 커밋 + merge |
| `tools/merge-feature.sh` | 이미 커밋된 feature만 merge |

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | 기획 vs 구현 스펙 층 · doc-layers 링크 |
| 2026-08-29 | Pages `/board/` 제거; 에이전트는 제목·본문만 추천 |
| 2026-08-28 | `/push` 칸반 자동 생성·열 이동 → **초안 추천** (사람이 Notion 관리) |
| 2026-07-22 | cat_dice 워크플로를 Afterburn에 이식한 요약 추가 |
