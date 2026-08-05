# 웹 스펙 뷰어 동기화

`docs/spec/*.md`를 `facility-weapon-modules` 이후 구현과 맞춰, 웹 스펙 뷰어(`docs/spec/index.html`)에서 최신 현황을 볼 수 있게 한다.

## 목표

- 오그먼트 풀 54(시설 12 · trait 28 포함)
- 동력로 · 실드 버퍼/재생 · 피격=1 · Shift 부스터 · 보조캐넌 포드 · 방벽 길이
- 컴포넌트·갭·씬 플로우 내비 설명 갱신

## AC

- [x] `docs/spec/` 카테고리 MD가 코드 현황과 모순 없음
- [x] 뷰어 사이드바 설명이 새 수치(54·시설 12 등)를 반영
- [x] 구형 문구(격납고 미정 · 풀 22 등) 제거

## 구현

- 2026-08-06 feature/docs-spec-viewer-sync → main (검증 대기)
