# Threat 엘리트 처치 게이트

## 목표

Threat가 찰 때마다 엘리트 1기를 소환하고, 엘리트를 처치해야 적 증강 오퍼가 열리며 일반 Encounter가 재개되게 한다.

## AC

- [x] 60초마다 다음 Threat 엘리트 1기가 등장하고, 처치 순간 Threat가 상승한다.
- [x] 엘리트 전투와 적 증강 오퍼가 끝날 때까지 일반 Encounter 생성이 정지한다.
- [x] 엘리트 처치 전에는 적 증강 오퍼가 열리지 않는다.
- [x] 엘리트 처치 후 기존 적 증강 3지선다가 열리고 선택 결과가 이후 적에게 적용된다.
- [x] 엘리트는 화면 상단을 순찰하며 주기적인 전방 2연사와 플레이어 위치 집중 연사를 사용한다.

## 구현

- 2026-08-21 feature/threat-elite-progression
- 2026-08-28 feature/threat-elite-progression → main (verification pending)
