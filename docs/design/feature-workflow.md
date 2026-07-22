# Feature 워크플로 요약

상세 정본: `.cursor/skills/feature/SKILL.md`, `.cursor/skills/push/SKILL.md`

## `/feature <설명>`

1. slug 추론 → `./tools/start-feature.sh <slug>`
2. 칸반 카드 생성/이동 (`speccing`/`doing`)
3. `docs/design/systems/<slug>.md` 작성·갱신
4. `docs/design/tasks/<slug>-tasks.md` Task 분리
5. 스펙 범위 안만 구현
6. Audit → 사용자 확인 후 `/push`

## `/push`

1. 스펙·Task·diff 정합성
2. 칸반 카드 → `review`
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
| 2026-07-22 | cat_dice 워크플로를 Afterburn에 이식한 요약 추가 |
