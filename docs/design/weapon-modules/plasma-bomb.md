# 무기 모듈 · 플라즈마 폭탄

- 무기 ID: `plasma_bomb`
- 획득 카드: `acquire_plasma_bomb`

## 기본 공격

- 본탄은 위로 이동하며 적의 피격 부위에 닿거나 플레이필드 경계에 도달하는 순간 폭발한다. 시간 경과만으로 폭발하지 않는다.
- 실제 무기 씬 기준 이동 속도 66px/s, 접촉 판정 반경 4px, 발사 간격 1.2초. 맵 끝은 탄 중심이 현재 플레이필드 뷰포트의 경계에 닿는 지점이다.
- 폭발은 순간 원형 범위 공격이다. 실제 무기 씬 기준 피해 32·반경 32px이며 범위 안의 모든 적 피격 부위에 한 번씩 피해를 준다. 앞의 적이나 Tanker 실드에 가려진 본체도 범위 안이면 타격한다. 무적은 무시하지 않는다.
- 접촉 자체의 별도 직격 피해는 없다. 여러 적과 동시에 닿거나 경계와 접촉이 겹쳐도 한 번만 폭발한다. 이동 경로를 검사해 한 물리 프레임에 적을 통과하는 경우도 접촉을 감지한다.
- 폭발 판정 반경은 blast_radius + damage_radius_margin이며 기본 여유값은 0이다. 시각 반경은 blast_radius를 사용한다.
- 클러스터 자탄은 접촉·경계 폭발에 더해 기존 0.35초 신관을 유지한다. 자탄이 다시 자탄·잔류장을 생성하지 않는다.

## 검증

`tests/plasma_bomb_weapon_smoke_test.gd`: 접촉 전 생존, 고속 이동 중 접촉, 맵 끝 폭발, 범위 관통·중복 방지·범위 밖 제외, 다수 표적, 클러스터·잔류장과 발사 시점 피해 배율 보존.

## 외형

![플라즈마](sprites/weapon_plasma_bomb.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_plasma_bomb.svg`
- 타격 이펙트: [공용 규칙](../effects.md#타격-이펙트) · 프로필 `effects/impact_profiles/plasma_bomb.tres`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 등급 | 표시명(요지) |
|----------|---------|------|--------------|
| `plasma_expand` | `trait_plasma_expand` | 실버 | 확장 폭심 — 폭발 반경 ×1.1→1.5 |
| `plasma_bomb_power` | `trait_plasma_bomb_power` | 실버 | 고밀도 코어 — 피해 ×1.08→1.40 |
| `plasma_cluster` | `trait_plasma_cluster` | 골드 | 클러스터 — 주 피해 ×0.9 · 소형 3→5발 · 각 40%→50% |
| `plasma_field` | `trait_plasma_field` | 골드 | 잔류 장 — 피해 ×0.95 · 지속 3→5초 · 최대 보너스 ×1.0→1.5 |
| `plasma_gravity` | `trait_plasma_gravity` | 골드 | 중력 수축 — 피해 ×1.35→1.65 · 흡인 240→360 · 폭발 반경 ×0.9 · 흡인 반경 배율 ×1.6→2.0 |

실버 수치는 Lv.I→V, 골드는 Lv.I→III이다.

플라즈마 본체·자탄·잔류장은 발사 시점의 일반/보스 피해 배율을 값으로 보존한다.

상위: [무기 모듈](index.md)
