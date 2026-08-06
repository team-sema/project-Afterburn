# 문서 정합성 감사

프로젝트 구조 전수 검토에서 드러난 **문서·규칙 간 모순**을 정리한다. 게임 코드는 건드리지 않는다.

## 문제

| # | 문제 | 위치 |
|---|------|------|
| 1 | 오그먼트 트리거를 **점수 기반**으로 설명 (실제는 XP·시간) | `.cursor/rules/afterburn-project.mdc`, `README.md` |
| 2 | 적 증강 풀 수 **3** 표기 (실제 6) | `docs/spec/overview.md` 스펙 트래킹 표 |
| 3 | 카드·인덱스 열 불일치 2건 | `docs/board/cards.json`, `docs/design/systems/README.md` |
| 4 | 오퍼 풀 **22/3** 표기 · 완료 항목이 `ready`/`doing`으로 남음 | `docs/design/augment-todo.md` |
| 5 | headless 실행법이 래퍼(`tools/run-godot.cmd`)와 실행 파일 직접 호출로 이원화 | `.cursor/rules/godot-development.mdc` vs `AGENTS.md` |
| 6 | 폴더 맵에 `pickups/`·`weapon_test/`·`tests/`·루트 조립 파일 누락 | `docs/spec/overview.md`, `godot-development.mdc` |
| 7 | 구조 부채(씬 인라인 풀·그룹 조회·trait 중복 등)가 어디에도 기록되지 않음 | `docs/spec/gaps.md` |

## 동작 (AC)

1. **오그먼트 트리거 정본화** — 규칙·README가 `docs/spec/augments.md`와 같은 설명(XP 충족 후 `C`, 적 60초 주기)을 쓴다. 점수는 표시·기록용임을 명시한다.
2. **수치 동기화** — `overview.md` 트래킹 표의 적 풀 수가 `augments.md`(6종)와 일치한다.
3. **열 정합성** — 머지된 `fix-formation-viewport-before-tree`(`bfa5795`, main 포함)는 카드 `review`. `status-ui-templates`는 카드·인덱스 모두 `review`.
4. **아이디어 보드 정리** — `augment-todo.md`의 풀 수를 54/6으로 고치고, 출하된 동력로·실드 재생 절은 `done`(초안 이력)으로 표시한다. **초안과 실제 출하 수치의 차이를 표로 남긴다** (수치를 조용히 덮어쓰지 않는다).
5. **Godot 실행 단일 경로** — 규칙이 `tools/run-godot.cmd`만 안내하고 실행 파일 직접 호출 예시를 제거한다. 판정 기준(종료 코드 + PASS)을 포함한다.
6. **폴더 맵 최신화** — 실제 디렉터리와 루트 조립 파일을 반영한다.
7. **구조 부채 기록** — `gaps.md`에 항목 17~22로 추가한다 (씬 인라인 풀, 그룹 조회, trait 이원화, 루트 배치, 테스트 베이스 부재, Jolt 사문 설정).

## 범위 밖 (별도 카드)

- 실제 리팩터(`gameplay.tscn` 데이터 드리븐화, 루트 파일 이동, 그룹 → 주입 전환) — `gaps.md` 17·18·20 및 `augment-pool-data-driven` 카드.
- `review` 38장 사람 검증 → `done` 이동.
- **엔진 버전 확정** — `project.godot`은 `config/features` `4.7`, 문서·규칙도 4.7이지만 `tools/run-godot.cmd` 기본값과 설치본은 `Godot_v4.6-stable_mono_win64`. 팀 확인 필요.

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-06 | 초안 · 구조 검토에서 나온 문서 모순 7건 정리 |
