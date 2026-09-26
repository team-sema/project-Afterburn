# 무기 모듈 · 블래스터

- 무기 ID: `main_blaster`
- 획득 카드: `acquire_main_blaster`

## 외형

![블래스터](sprites/weapon_main_blaster.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_main_blaster.svg`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 등급 | 표시명(요지) |
|----------|---------|------|--------------|
| `blaster_rapid_loader` | `trait_blaster_rapid_loader` | 실버 | 고속 급탄기 — 연사 간격 ×0.93→0.71 |
| `main_blaster_power` | `trait_main_blaster_power` | 실버 | 증폭 약실 — 피해 ×1.08→1.40 |
| `blaster_sync_trigger` | `trait_blaster_sync_trigger` | 골드 | 동기화 방아쇠 — 좌우 동시 · 피해 ×0.85→1.0 · 간격 ×1.15→1.0 |
| `blaster_accel_ap` | `trait_blaster_accel_ap` | 골드 | 가속 철갑탄 — 관통 +1→+3 · 탄속 ×1.3→1.6 · 관통 후 ×0.7→0.9 |
| `blaster_ricochet` | `trait_blaster_ricochet` | 골드 | 도탄 탄자 — 최대 2회 · 도탄 피해 70/40%→90/70% |
| `blaster_split_prism` | `trait_blaster_split_prism` | 프리즘 | 연쇄 분열탄 — 명중 시 3발 분열(최대 2단계) · 피해 ×0.6 |

실버 수치는 Lv.I→V, 골드는 Lv.I→III이다.

도탄 직후 같은 적에게 곧바로 다시 닿지 않도록 판정을 0.03초 끄며, 이 대기는 트리 일시정지 동안 멈춘다.

### 연쇄 분열탄 (프리즘)

- 본탄 피해가 ×0.6이 된다. 본탄이 처음 적 피격 부위에 맞으면 그 자리에서 진행 방향 기준 −45°·0°·+45° 세 방향으로 분열탄 3발이 나간다(`split_count` 3 · `split_spread_deg` 90).
- 분열탄은 부모와 같은 피해·탄속을 이어받고 관통·도탄은 없다. 부모와 조상이 맞힌 적은 맞히지 않는다.
- 분열탄도 처음 맞힐 때 한 번 더 분열하며 본탄 기준 최대 2단계(`split_generations`)까지다. 본탄 1발에서 최대 13발이 나온다.
- 본탄은 분열한 뒤에도 기존 관통·도탄 규칙을 그대로 따른다. 분열탄은 물리 콜백 밖에서 생성한다.
- 대가: 군집에는 연쇄로 강하지만 단일 표적(보스)에는 분열탄이 비껴 나가 본탄 피해 ×0.6만 남는다.

## 완료 조건·검증

- 연쇄 분열탄 본탄이 적에 맞으면 3발로 분열하고, 분열탄은 부모가 맞힌 적을 다시 맞히지 않으며, 2단계를 넘어 분열하지 않는다 (`tests/blaster_split_prism_smoke_test.gd`).

상위: [무기 모듈](index.md)
