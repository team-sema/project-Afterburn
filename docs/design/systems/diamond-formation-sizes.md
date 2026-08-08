# 다이아몬드 편대 크기 (5 / 13)

## 목표

기존 마름모 호위를 **5기 풀필**로 조밀화하고, Threat 2+용 **13기** 대형 마름모를 추가한다. Encounter id에 기수를 명시한다. 진입 후 패트롤 대신 **산개**한다.

## 동작

| 항목 | 5기 | 13기 |
|------|-----|------|
| Encounter ID | `striker_drone_diamond_5` | `striker_drone_diamond_13` |
| 레이아웃 | `diamond_formation.tscn` (`DiamondFormation5`) | `diamond_formation_13.tscn` (`DiamondFormation13`) |
| 슬롯 | 5 (꼭짓점+중심) | 13 (1-3-5-3-1) |
| 배치 | Slot0 Striker · Slot1–4 Drone | Slot0 Striker · Slot1–12 Drone |
| 간격 | ±32x / ±28y | step 20 |
| difficulty | 7 | 15 |
| min_threat | 1 | 2 |
| 편대 이동 | `formation_entry_third` (y≈1/3, 40px/s) | 동일 |
| 해제 | `SEQUENCE_FINISHED` | 동일 |
| Drone 산개 | `individual_scatter_2_5` (100px/s = ×2.5, 외향) | 동일 |
| Striker 산개 | `individual_striker_charge_2_5` (100px/s, 플레이어 방향) | 동일 |

구 id `striker_drone_diamond`(팁 비움·멤버 4·패트롤)는 제거한다.

## 비범위

- 사격 수치 재밸런스
- 다른 편대 레이아웃 간격 변경
- midmap drone 산개 배율 변경은 이 피쳐에서 `individual_scatter_double`을 ×2.5(150)로 맞춤 (inverted 포함)

## AC

1. 5기 편대는 팁(Slot4)까지 Drone이 채워져 멤버 5명이다.
2. 13기 Encounter가 Pool에 min_threat 2로 등록된다.
3. 5기 슬롯 좌표가 ±32/±28로 조밀하다.
4. 1/3 지점 도착 후 패트롤 없이 산개한다. Drone 외향 · Striker 플레이어 돌진 · 이속 ×2.5.
5. `docs/spec/enemies.md`와 스모크 테스트가 위 표와 일치한다.

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-09 | 패트롤 제거 · 1/3 진입 후 ×2.5 산개 · Striker 플레이어 돌진 |
| 2026-08-09 | 초안 · 5기 조밀화·팁 채움 · 13기 추가 · id 명시 |
