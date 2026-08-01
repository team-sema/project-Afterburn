# Bomb 씬 uid 정정

## 문제

`enemies/bomb_enemy.tscn`의 씬 uid가 손으로 적은 `uid://cbombenemy0001`이었다. Godot이 이를 유효하지 않게 보고 에디터를 열 때마다 실제 uid로 다시 써서, 작업자마다 커밋되지 않은 변경이 계속 생겼다.

## 변경

- 씬 헤더 uid를 Godot이 생성한 `uid://dyoidordek441`로 확정.

## 안전성

- 저장소 어디에서도 `uid://cbombenemy0001`을 참조하지 않는다 (스폰 세트 `resources/enemy_spawns/bomb.tres`, 테스트, 문서 모두 **경로** 참조).
- 동작·수치 변화 없음 → 현황 스펙 해당 없음.

## AC

- [x] 에디터를 열어도 `bomb_enemy.tscn`이 다시 수정되지 않는다
- [x] `bomb_proximity_fuse_smoke_test` OK
- [x] Bomb 스폰 경로(`bomb.tres`)가 그대로 동작한다

## 구현

- 2026-08-02 `enemies/bomb_enemy.tscn` uid 확정, feature/fix-bomb-enemy-scene-uid → main (검증 대기)
