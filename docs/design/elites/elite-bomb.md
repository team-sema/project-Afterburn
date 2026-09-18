# Elite Bomb

## 구현 상태

외형 시안만 존재한다. 일반 [bomb](../enemies/bomb.md)와 별개의 적으로 관리한다. 일반 적의 HP·공격·보상을 자동 승계하지 않는다. 전용 씬·전투 패턴·수치·등장 조건은 미결정이며 현재 엘리트 로스터에 포함하지 않는다.

## 외형 시안

![Elite Bomb concept](../enemies/sprites/enemy_elite_bomb.svg)

- 일반 Bomb의 덩어리감을 계승한 **중장갑 기뢰**. 상단 신관과 점화 팁을 제거하고, 사방이 대칭인 각진 외피로 압축된 폭발체를 표현한다.
- 상하좌우 장갑의 안쪽에 짧고 각진 투명 절개를 배치한다. 중앙의 작은 마름모 절개와 넓은 흰색 몸체로 묵직한 덩어리를 유지한다.
- 외곽은 낮은 턱이 있는 일체형 장갑이다. 위쪽 돌출부나 몸체와 떨어진 부유 부품은 두지 않는다.
- 흰색 SVG 마스크에 기존 엘리트의 적색/분홍 글로우·연분홍 흰색 코어를 적용한다.
- 에셋: `assets/svg/enemy_elite_bomb.svg` (128×128). 표시 배율 0.25 × 1.35에서 약 43×43px이며, 확대와 실제 표시 크기를 비교한다.
- 외형 시안 단계다. 전용 씬·자폭 동작·보상·Threat 편성은 미정이며 실제 전투에는 연결하지 않는다.
- 미리보기: `artifacts/elite_bomb_design.png`. 재생성: `tools/run-godot.cmd --rendering-method gl_compatibility --script res://artifacts/preview_elite_bomb.gd`.

## 완료 조건·검증

- 현재 검증 대상은 SVG와 미리보기 스크립트의 외형이다.
- 전투 구현 전 이 문서에서 의도·패턴·수치·등장 조건·보상과 검증 조건을 확정한다.
