---
name: push
description: Default end-of-feature command. Commit with generated message, stop if origin/main updated, else merge to main. Use for /push when finishing feature work.
disable-model-invocation: true
---

# Push (feature 완료 → main) — **기본 종료 명령**

**언제:** 피쳐 개발이 **끝났을 때** (거의 항상 이것만 사용).  
**브랜치 시작:** `./tools/start-feature.sh <slug>` (또는 `git checkout -b feature/<slug>`).

`feature/*`에서 **커밋 → origin/main 신규 여부 확인 → 없으면 main merge & push**.  
`origin/main`에 새 커밋이 pull 되면 **머지하지 않고 중단**(exit 2).

## 명령

```
/push
/push --no-delete   # 머지 후 feature 브랜치 유지 (예외)
```

## 절차 (순서 고정)

### 1. 브랜치·상태·범위

```bash
git branch --show-current
git status
git diff
git diff --staged
git diff --stat
```

- `feature/*`가 아니면 중단하고 `tools/start-feature.sh` 안내.
- 변경 없고 이미 커밋만 남은 경우 → `-m` 없이 스크립트 실행 가능.
- `git diff --stat`이 이번 feature slug·요청과 안 맞으면: **에이전트가** 범위 이탈로 경고 (`feature-scope` rule).

### 2. 문서·코드 정합성 (필수 — 스크립트 실행 전)

브랜치명에서 slug 추출: `feature/<slug>` → `docs/design/systems/<slug>.md`, `docs/design/tasks/<slug>-tasks.md`, **관련 `docs/spec/*.md`**를 읽고 `git diff`와 대조한다. **불일치 시 push 중단**.

**체크리스트:**

| # | 확인 | 불일치 시 |
|---|------|-----------|
| 1 | 시스템 스펙 존재·이번 feature와 동일 slug | 스펙 없으면 생성 또는 slug 확인 |
| 2 | Acceptance Criteria ↔ 실제 구현 | 스펙 또는 코드 수정 |
| 3 | Task 완료 조건·수정 예상 파일 ↔ `git diff --stat` | Task 또는 diff 정리 |
| 4 | 코드 변경이 스펙·Task에 **근거** 있음 | 스펙 먼저 갱신 |
| 5 | **수정 금지** 미변경: 오그먼트 오퍼 임계·물리 레이어·스폰 공식 등 (이 feature 스펙에 명시된 범위 외) | 별도 feature로 분리·되돌림 |
| 6 | 스펙·Task 변경 시 `## 변경 이력` 한 줄 (`docs-and-plans`) | 이력 추가 |
| 7 | **칸반 티켓** (`kanban-tickets`): slug 카드 `column`=`review`, MD 이력·`cards.json` 갱신 후 **이 커밋에 포함** | 티켓 누락 시 중단 |
| 8 | **현황 스펙 `docs/spec/` 필수** — 동작·수치·타입·입력·스폰·탄·UI가 바뀌면 관련 카테고리 MD가 **이 커밋/diff에 포함**되고 코드와 모순 없음. 연쇄 문서(`combat` 점수표·`gaps`·`overview` 루프 등)도 같이 맞춤. 순수 리네임·버그픽스·테스트만이면 diff에 스펙 없어도 되나 응답에 **「현황 스펙 해당 없음: …」** 명시 | 스펙 갱신 없이 push 금지 |

**출력:**

```markdown
### Push 전 정합성
- slug: <slug>
- 스펙: docs/design/systems/<slug>.md — (OK / 이슈)
- 현황 스펙: docs/spec/<관련>.md — (OK · 파일 목록 / 해당 없음: 이유 / 이슈)
- Task: docs/design/tasks/<slug>-tasks.md — (OK / 없음 / 이슈)
- AC ↔ 구현: (OK / 이슈 요약)
- diff 범위: (OK / 이슈)
- 수정 금지 파일: (미변경 / 이슈)
- 티켓: <id> → review (OK / 생성함 / 이슈)
```

### 3. 커밋 메시지 작성

접두: `feat:`, `fix:`, `docs:`, `godot:` + 영문 짧은 설명.

### 4. 스크립트 실행

```bash
chmod +x tools/push-feature.sh tools/merge-feature.sh 2>/dev/null || true
./tools/push-feature.sh -m "feat: short description"
# 브랜치 유지가 필요할 때만: ./tools/push-feature.sh -m "..." --no-delete
```

### 5. exit 2 (STOP)일 때

**force push 금지.** feature에서 `git merge main` → 충돌 해결·Godot 확인 → `/push` 재실행.

### 6. 성공 시

팀원: `git checkout main && git pull`

## 하지 않음

- `git push --force`, `git config` 변경
- STOP 상태에서 main에 feature merge 시도
- GitHub PR 생성 (필수 아님)

## 관련

- 브랜치 시작: `./tools/start-feature.sh <slug>`
- 이미 커밋됨·머지만: `./tools/merge-feature.sh`
