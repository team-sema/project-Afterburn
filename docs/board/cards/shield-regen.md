# 실드 재생 · 충전 UI

실드가 깎이면 **즉시** 소형 게이지가 차기 시작하고, 꽉 차면 실드 +1.

## AC

- [x] 깎이면 즉시 충전 (무피격 대기 없음)
- [x] 피격 → 게이지 리셋 후 **바로** 다시 충전
- [x] 충전 완료 전엔 그 칸으로 방어되지 않음
- [x] HUD: 실드 바 아래 소형 게이지
- [x] 시작 실드 1 (`shield-base-one`)
- [x] 실드는 버퍼 HP (초과분은 선체; 플레이어 피격은 이벤트당 1)

## 스펙

- `docs/design/systems/shield-regen.md`

## 구현

- 2026-08-06 `feature/facility-weapon-modules` → main (검증 대기)
