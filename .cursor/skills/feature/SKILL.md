---
name: feature
description: >-
  End-to-end feature workflow for Project Afterburn: document first, task breakdown,
  implementation, self-audit, summary. Use for /feature or when the user requests
  a new game feature. Never implement before spec exists.
disable-model-invocation: true
---

# Feature Skill

## 목적

`/feature`는 사용자가 새 기능 아이디어를 입력했을 때, AI가 즉시 코드부터 수정하지 않고 아래 플로우를 강제로 따른다.

**문서 업데이트 → Task 분리 → 구현 → 자체 Audit → 결과 요약**

이 스킬의 핵심 목적은 AI가 스펙에 없는 기능을 임의로 추가하거나, 기존 규칙을 마음대로 바꾸는 것을 방지하는 것이다.

## 명령어 형식

```
/feature <기능 설명>
```

예:

```
/feature 플레이어 오그먼트에 behavior_components가 있으면 Ship에 붙여서 적용한다.
```

## 최우선 규칙

사용자의 Feature 요청은 아이디어가 아니라 **구현 스펙의 출발점**이다.

AI는 사용자의 Feature를 임의 해석해 확장하지 않는다.

항상 다음 순서를 지킨다:

**브랜치 생성 → 문서화 → Task 분리 → 구현 → Audit → 결과 요약**

**모든 편집(문서·Task·코드)은 `feature/<slug>` 브랜치에서만** 한다. `main`이나 다른 `feature/*`에서 구현하지 않는다.

코드를 수정하기 전에 반드시 관련 문서를 먼저 찾고 업데이트한다. 문서에 적히지 않은 기능을 코드로 구현하지 않는다.

---

## 실행 원칙

### 1. 문서 우선

관련 문서가 없으면 새 문서를 생성한다.

문서에는 최소한 아래 내용을 포함한다:

- 기능 목적
- 동작 조건
- 표시 정보
- 계산 방식 (해당 시)
- 예외 조건
- 영향받는 시스템
- Acceptance Criteria

### 2. 문서 없는 코드 수정 금지

기능 구현 중 문서에 없는 판단이 필요하면 임의로 구현하지 말고 **TODO 또는 질문**으로 남긴다.

### 3. Task 분리

문서 업데이트 후 구현 전에 Task를 분리한다. Task는 **구현 순서** 기준으로 작성한다.

각 Task에는 아래 내용을 포함한다:

- Task 이름
- 목적
- 수정 예상 파일
- 수정 금지 파일
- 완료 조건

### 4. 구현

Task 목록을 기준으로 기능을 구현한다.

- 스펙에 없는 기능 추가 금지
- 기존 룰 임의 변경 금지
- 기존 파일 구조 임의 변경 금지
- 기존 public API 임의 변경 금지
- 관련 없는 리팩터링 금지
- UI/연출 과잉 구현 금지

필요한 경우 새 파일은 생성할 수 있으나, 생성 이유를 결과 요약에 남긴다.

### 5. 자체 Audit

구현 후 반드시 문서와 실제 구현을 비교한다.

확인 항목:

- 문서에 적힌 기능이 구현되었는가?
- 문서에 없는 기능이 추가되었는가?
- 수정 금지 파일을 건드렸는가?
- 오그먼트·점수 임계·물리 레이어·스폰 규칙을 스펙 없이 바꿨는가?
- Acceptance Criteria를 만족하는가?
- 테스트 또는 수동 검증 방법이 존재하는가?
- `feature/<slug>` 브랜치에서만 편집했는가?

Audit 출력 형식:

```markdown
## Audit 결과

### 통과
- ...

### 확인 필요
- ...

### 미구현
- ...

### 스펙 외 변경
- ...
```

---

## 피드백 라운드 (별도 스킬 입력 불필요)

`/feature`로 시작한 **같은 대화**에서 사용자가 수정·피드백을 주면, `/change`나 다른 스킬을 다시 치지 않아도 **이 섹션을 자동 적용**한다.

### 매 피드백마다 (순서 고정)

1. **스펙** — `docs/design/systems/<slug>.md` (동작·표시·AC 변경 시). 현황 스펙 `docs/spec/`은 머지 후 또는 필요 시.
2. **Task/AC** — `docs/design/tasks/<slug>-tasks.md` 완료 조건·수정 파일 갱신.
3. **코드** — 스펙에 반영된 내용만 구현.
4. **미니 Audit** — 응답 말미에 3~5줄.

스펙에 없는 변경은 코드로 하지 않는다. 사용자가 “문서 말고 코드만”이라고 해도 **동작·표시·조건**이 바뀌면 스펙을 먼저 고친다.

### 미니 Audit 형식

```markdown
### 미니 Audit
- 스펙 반영: (변경 요약 또는 “해당 없음”)
- AC/Task 갱신: (Y/N)
- 코드만 변경: (Y/N — Y면 스펙 영향 없는 리네이밍·버그만 해당)
```

### 완료 신호

사용자가 “완료”, “이대로 push”, “OK” 등으로 끝내면 **전체 Audit**(위 §5)을 한 번 더 수행한 뒤 `/push` 안내.

---

## 금지 사항

- 문서 수정 없이 코드부터 수정
- 스펙에 없는 기능 추가
- 오그먼트 풀·점수 임계·물리 레이어를 스펙 없이 변경
- 관련 없는 UI 개선·리팩터·파일 구조 대규모 변경
- 요청하지 않은 애니메이션 추가
- `main` 또는 다른 `feature/*` 브랜치에서 파일 수정

---

## 프로젝트 문서 경로 (Afterburn)

| 용도 | 경로 |
|------|------|
| 구현 현황 | `docs/spec/` |
| 시스템 스펙 | `docs/design/systems/<slug>.md` |
| Task 문서 | `docs/design/tasks/<slug>-tasks.md` |
| 칸반 | `docs/board/` |
| 비주얼 | `.agents/godot_nova_drift_visual_guide.md` |

문서 수정 시 `docs-and-plans` rule: 본문 직접 갱신, 맨 하단 `## 변경 이력` 추가 (최신이 위).

시스템 스펙 신규·갱신 시 `docs/design/systems/README.md` 인덱스에 한 줄 추가한다.

---

## Feature slug

요청에서 **짧은 영문 slug**를 추론한다 (예: `player-augment-behaviors`).

- 소문자·숫자·하이픈만
- 브랜치명: `feature/<slug>`
- 스펙·Task·칸반 카드 id에도 동일 slug 사용

## 전체 플로우

### Step 1. 입력 해석

Feature를 **한 문장**으로 요약하고 **feature slug**를 정한다.

### Step 2. Feature 브랜치 생성 (필수 — 모든 편집 전)

```bash
git branch --show-current
git status --porcelain
```

| 현재 상태 | 동작 |
|-----------|------|
| 이미 `feature/<slug>` | 그대로 진행 |
| `feature/<다른-slug>` | 이 feature와 무관하면 중단 |
| `main` 등, `feature/<slug>` 없음 | `./tools/start-feature.sh <slug>` |
| `feature/<slug>` 이미 존재 | `git checkout feature/<slug>` |

working tree가 깨끗해야 한다. 브랜치 전환 후 응답 **맨 앞**:

`브랜치: feature/<slug> · 범위: components/... · player_ship/... (2~5개 경로)`

칸반: `kanban-tickets` — slug 카드 찾거나 만들고 `speccing`/`doing`으로.

### Step 3. 관련 문서 탐색

- `docs/spec/` 관련 카테고리
- `docs/design/systems/`
- 기존 feature 문서

없으면 `docs/design/systems/<feature-slug>.md` 신규.

### Step 4. 문서 업데이트

```markdown
# Feature: <기능명>

## 목적

## 동작 조건

## 표시 정보

## 계산 방식

## 예외 조건

## 영향받는 시스템

## Acceptance Criteria

## 구현 메모
```

### Step 5. Task 생성

`docs/design/tasks/<feature-slug>-tasks.md`

### Step 6. 구현 (반드시 `feature/<slug>`에서)

`feature-scope` rule. Godot 4.7, `context7-godot`로 API 확인.

### Step 7–8. Audit + 결과 요약

커밋·push는 사용자가 요청할 때만 (`/push`).

---

## 다른 스킬과의 관계

| 스킬 / 스크립트 | 역할 |
|-----------------|------|
| `./tools/start-feature.sh` | `/feature` Step 2 |
| `/feature` | 브랜치 → 문서 → Task → 구현 → Audit |
| `/push` | feature 완료 후 main 반영 |

---

## 추가 자료

[examples.md](examples.md)
