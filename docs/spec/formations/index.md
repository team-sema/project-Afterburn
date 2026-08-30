# 진형 (Formation)

진형 = **슬롯 기하만**. 어떤 적이 앉는지·어떻게 움직이는지는 [Encounter](#encounters)가 정한다.

같은 레이아웃을 여러 Encounter가 재사용한다 (예: Diamond5 → Striker 호위 / Bomb 호위).

코드: `formations/layouts/*.tscn` · `FormationLayout` / `FormationSlot`

## 풀에서 쓰는 레이아웃

| 레이아웃 | 슬롯 | 상세 |
|----------|------|------|
| Horizontal | 5 | [horizontal](#formations/horizontal) |
| Diamond5 | 5 | [diamond-5](#formations/diamond-5) |
| Diamond13 | 13 (1-3-5-3-1) | [diamond-13](#formations/diamond-13) |
| V3 | 3 | [v3](#formations/v3) |
| V5 / V7 | 5 / 7 | zigzag·하강 계열 |
| X9 | 9 | [x9](#formations/x9) |
| InterceptorPair | 2 | [interceptor-pair](#formations/interceptor-pair) |
| Single | 1 | [single](#formations/single) |

## 작성 규칙

- 오프셋·슬롯 이름만 기록
- 멤버 배치는 Encounter MD / [catalog](#encounters/catalog)에
- 신규 진형 feature → 이 폴더에 페이지 추가 + Encounter에서 링크
