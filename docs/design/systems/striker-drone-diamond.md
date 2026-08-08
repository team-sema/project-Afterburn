# Striker 드론 호위 마름모

> 후속: `diamond-formation-sizes` — id를 `_5`/`_13`으로 분리, 팁 채움·13기 추가, 패트롤 제거 후 ×2.5 산개(Striker는 플레이어 돌진).

## 목표

Threat 1에서 `striker_single`을 제거하고, Striker가 최후방에 있고 전방 3슬롯 Drone이 방패가 되는 마름모 Encounter로 교체한다.

## 동작

| 항목 | 규칙 |
|------|------|
| Encounter ID | `striker_drone_diamond` (후속 피쳐에서 `_5`/`_13`으로 교체) |
| 레이아웃 | `DiamondFormation` |
| 배치 | Slot0(`top`) Striker · Slot1–3 Drone · Slot4 비움 |
| 이동 | `formation_entry_third_patrol` — 뷰포트 높이 ≈1/3 직하강 후 좌우 패트롤 |
| 편대 해제 | `NEVER` (Maintain) |
| Pool weight | Threat 1/2/3 모두 6 (기존 `striker_single` 자리) |

## 비범위

- `striker_single.tres` 파일 삭제 (단일 해제 스모크용으로 유지)
- Drone 5기 일자 편대·Threat 3 V7/X9 변경
- 사격 수치 재밸런스

## AC

1. `MainEncounterPool`에 `striker_single`이 없고 `striker_drone_diamond`가 동일 weight로 들어간다.
2. 스폰 시 멤버 4명: 후방 Striker 1 + 전방 Drone 3.
3. 편대 중심이 맵 약 1/3 지점까지 내려온 뒤 좌우로 왕복한다.
4. `docs/spec/enemies.md`가 위 동작과 일치한다.

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-09 | 후속 `diamond-formation-sizes`로 이관 표기 |
| 2026-08-08 | V3/V5/InvertedV5 레이아웃 명칭 정리 |
| 2026-08-08 | 초안 · Striker 단독 → 마름모 호위 편대 |
