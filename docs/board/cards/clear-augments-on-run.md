# 런 시작 시 clear_augments

## 현황

`clear_augments()`는 구현만 있고 호출처가 없다. 새 World가 빈 레지스트리로 시작한다고 가정한다.

## 목표

World `_ready` 또는 메뉴→World 진입 시 양 레지스트리를 명시적으로 clear해 재진입/핫리로드 이슈를 줄인다.
