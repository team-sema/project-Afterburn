# Tanker 피격 피드백 강화

## 목표

Tanker 전방 실드 피격이 Core만 짧게 깜빡여 티가 안 나던 문제를 고친다. 일반 `Enemy` 본체와 같이 **스케일 펀치 + 화이트 플래시 + 쉐이크**를 실드 Visual에 적용한다.

## 동작

| 항목 | 규칙 |
|------|------|
| 트리거 | `Shield/HurtboxComponent.hurt` |
| Scale | `Shield/Visual` ×**1.08**, 0.2s (기존 1.35가 과한 펀치의 주원인) |
| Flash | `flash_root` = `Shield/Visual` (Wide/Tight/Core 전부), 0.2s |
| Shake | 실드 **사용 안 함** (호출 제거) |
| 사격 | 없음 — `EnemyShootComponent`를 `_enter_tree`에서 제거 |
| 본체 | Scale ×1.1 · Shake 0.5 (레이저 관통 시 본체 피드백도 약하게) |

## AC

1. 실드 피격 시 Visual 자식에 플래시 머티리얼이 걸린다.
2. 실드 피격은 shake를 돌리지 않는다.
3. Tanker는 투사체를 발사하지 않는다.
4. `docs/spec/enemies.md` · `effects.md` · `components.md`와 일치.

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-09 | 실드 쉐이크 제거 · 스케일 1.35→1.08 (과한 모션 주원인) · 본체도 약화 |
| 2026-08-09 | 사격 제거 · 쉐이크 1.25→0.45 / 0.25→0.15s |
| 2026-08-09 | 쉐이크 3→1.25 · duration 0.35→0.25 (과한 떨림 완화) |
| 2026-08-09 | 초안 · 실드 hit feedback 정렬 |
