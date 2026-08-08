# Striker 드론 호위 마름모

## 목표

Striker 1기 단독 스폰을 없애고, 최후방 Striker + 전방 Drone 3기 마름모 호위 편대로 교체. 맵 약 1/3 하강 후 좌우 패트롤.

## AC

- Pool에 `striker_drone_diamond` (weight 6), `striker_single` 제외
- Slot0 Striker · Slot1–3 Drone · Slot4 비움
- `formation_entry_third_patrol` 이동

## 구현

- 2026-08-08 `feature/striker-drone-diamond` → main (검증 대기)
- V 레이아웃 명칭: `v3_formation` / `v5_formation` / `inverted_v5_formation`
