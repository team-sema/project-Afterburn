# 무기 모듈 · 플라즈마 폭탄

- 무기 ID: `plasma_bomb`
- 획득 카드: `acquire_plasma_bomb`

## 외형

![플라즈마](sprites/weapon_plasma_bomb.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/svg/weapons/weapon_plasma_bomb.svg`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 표시명(요지) |
|----------|---------|--------------|
| `plasma_expand` | `trait_plasma_expand` | 팽창형 — 반경 ×1.6→2.2 · 피해 ×1.1→1.3 |
| `plasma_cluster` | `trait_plasma_cluster` | 집속 폭발 — 소형 3→5발 · 각 40%→50% |
| `plasma_field` | `trait_plasma_field` | 잔류 플라즈마장 — 지속 3→5초 · 최대 보너스 ×1.0→1.5 |
| `plasma_gravity` | `trait_plasma_gravity` | 중력 기폭 — 피해 ×1.35→1.65 · 흡인 240→360 |

플라즈마 본체·자탄·잔류장은 발사 시점의 일반/보스 피해 배율을 값으로 보존한다.

상위: [무기 모듈](index.md)
