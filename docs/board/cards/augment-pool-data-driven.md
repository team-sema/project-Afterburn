# 오그먼트 풀 데이터 드리븐화

## 현황

선택 후보는 `world.tscn`의 `AugmentOfferController` 익스포트 배열에 하드코드되어 있다. 풀 추가마다 씬 편집이 필요하다.

## 목표

`AugmentPool` Resource 또는 Registry 메타로 풀을 관리하고, `choices_per_offer`만 컨트롤러에 둔다.
