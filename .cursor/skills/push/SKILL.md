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

브랜치명에서 slug를 추출하고 관련 주제별 기획서와 `git diff`를 대조한다. 불일치 시 push를 중단한다. `docs/design/tasks/`는 사용하지 않는다.

완료된 변경은 기획서의 관련 본문·표·수치·완료 조건에 통합되어야 한다. `이번 변경`이나 변경 이력에만 구현 사실을 덧붙인 상태는 정합성 통과로 보지 않는다. 기존 문서의 구조는 유지하며 필요한 부분만 자연스럽게 고치고, 여러 문서에 같은 규칙을 복제하지 않는다.

**체크리스트:**

| # | 확인 | 불일치 시 |
|---|------|-----------|
| 1 | 관련 주제별 기획서가 변경 범위와 일치 | 기획서 경로·범위 확인 |
| 2 | 완료 조건 ↔ 실제 구현 | 기획서 또는 코드 수정 |
| 3 | 기획서의 수정 예상 범위 ↔ `git diff --stat` | 기획서 또는 diff 정리 |
| 4 | 코드 변경이 기획서에 **근거** 있음 | 기획서 먼저 갱신 |
| 5 | **수정 금지** 미변경: 오그먼트 오퍼 임계·물리 레이어·스폰 공식 등 (이 feature 스펙에 명시된 범위 외) | 별도 feature로 분리·되돌림 |
| 6 | 기획서 변경 시 `## 변경 이력` 한 줄 (`docs-and-plans`) | 이력 추가 |
| 7 | **칸반 티켓** (`kanban-tickets`): Notion 카드 **제목·본문 초안만** 추천. **자동 생성·열 이동·태그 설정 금지** | 추천 블록 누락 시 중단 |
| 8 | 동작·수치·UI 변경 시 관련 기획서가 같은 diff에 포함되고 구현과 일치. 연쇄 문서도 갱신. 규칙 영향이 없으면 생략 이유 보고 | 기획 갱신 없이 push 금지 |

**출력:**

```markdown
### Push 전 정합성
- slug: <slug>
- 기획서: <관련 주제 경로> — (OK / 해당 없음: 이유 / 이슈)
- AC ↔ 구현: (OK / 이슈 요약)
- diff 범위: (OK / 이슈)
- 수정 금지 파일: (미변경 / 이슈)

### 칸반 (수동)
- feature slug: `<slug>` (Notion `카드 ID` 후보)
- 기존 카드: (있음 · `<이름>` / 없음 · MCP 미연결)
- 추천 제목: …
- 추천 본문: …
- 카드 생성·열·태그는 사람이 Notion에서 한다.
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

## 하지 않음

- `git push --force`, `git config` 변경
- STOP 상태에서 main에 feature merge 시도
- GitHub PR 생성 (필수 아님)
- Notion 카드 자동 생성·열 이동 (Notion MCP 없음으로 push 중단 금지)
- `docs/design/tasks/` 체크리스트 생성

## 관련

- 브랜치 시작: `./tools/start-feature.sh <slug>`
- 이미 커밋됨·머지만: `./tools/merge-feature.sh`
