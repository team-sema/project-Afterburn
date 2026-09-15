# Task: drone-formation-catalog

## Canonical docs

- [formations/index.md](../formations/index.md) (+ 하위 진형 페이지)
- [enemies/drone.md](../enemies/drone.md)
- [encounters/catalog.md](../encounters/catalog.md)

## Scope

- `docs/design/formations/**`
- `docs/design/design.js`
- `docs/design/enemies/drone.md` · `docs/design/enemies/index.md` · `docs/design/enemies/tanker.md`
- `docs/design/encounters/catalog.md`
- `tools/gen_formation_diagrams.py`

## Work

1. 레이아웃 `.tscn` 슬롯 좌표로 배치 SVG 생성
2. 진형 카탈로그를 무기/적 목록처럼 표 + 미리보기로 정리
3. 드론 Encounter ↔ 진형 대응 표 추가
4. 누락 진형 페이지(V5/V7/Triangle6 등) 보강 · `design.js` 등록
5. 적 목록에서 빠졌던 Tanker 상세·내비 복구

## Verification

- [x] 문서 사이트에서 `#formations` · 하위 진형 페이지가 열리고 배치 그림이 보인다
- [x] SVG 슬롯 번호가 `.tscn`의 `slot_index`와 일치한다
- [x] `#enemies` / `#enemies/tanker`에 Tanker가 다시 보인다
