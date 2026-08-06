# 문서 정합성 감사

## 목표

구조 전수 검토에서 나온 문서·규칙 모순을 정리한다. 게임 코드는 손대지 않는다.

## AC

- 규칙·README가 오그먼트 트리거를 **XP·시간 기반**으로 설명 (점수는 표시용)
- `docs/spec/overview.md` 적 풀 수가 `augments.md`(6종)와 일치
- 카드·시스템 인덱스 열 불일치 2건 해소
- `augment-todo.md` 풀 수 54/6 · 출하 항목 `done` · 초안 대비 실제 수치 차이 명시
- headless 실행 안내가 `tools/run-godot.cmd` 단일 경로
- 구조 부채가 `docs/spec/gaps.md` 17~22로 기록

## 구현

- 2026-08-06 feature/docs-consistency-audit → main (검증 대기)

## 후속 (별도 카드)

- `gameplay.tscn` 데이터 드리븐화 · 루트 파일 정리 · 그룹 조회 → 주입 전환
- `review` 38장 사람 검증
- 엔진 버전 확정 (project.godot 4.7 vs 설치본 4.6)
