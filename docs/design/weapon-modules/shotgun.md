# 무기 모듈 · 샷건

- 무기 ID: `main_shotgun`
- 획득 카드: `acquire_main_shotgun`

## 외형

![샷건](sprites/weapon_main_shotgun.svg)

획득·특성 카드가 공유하는 무기 아이콘.
- 스프라이트: `assets/weapons/weapon_main_shotgun.svg`

## 강화 모듈 (WEAPON_TRAIT)

| trait_id | 카드 ID | 표시명(요지) |
|----------|---------|--------------|
| `shotgun_expanded_shell` | `trait_shotgun_expanded_shell` | 확장 산탄 — 펠릿 +4→+8 · 피해 ×0.85→0.75 |
| `shotgun_choke` | `trait_shotgun_choke` | 초크 — 산탄각 ×0.5→0.3 · 탄 수명 ×1.4→1.8 · 탄속 ×1.2→1.4 |
| `shotgun_cut_barrel` | `trait_shotgun_cut_barrel` | 단축 총열 — 근거리 피해 ×1.8→2.4 · 판정 거리 80→100 · 산탄각 ×1.5 · 탄 수명 ×0.85 |
| `shotgun_burst_device` | `trait_shotgun_burst_device` | 버스트 장치 — 3발마다→2발마다 추가 사격 · 피해 ×0.9→1.0 |

초크의 실제 사거리는 탄속과 수명의 곱으로 증가한다(Lv.I ×1.68, Lv.III ×2.52). 카드 리소스 설명의 “사거리 ×1.4”는 수명 배율을 지칭하는 부정확한 표기이며 설명 문자열 수정이 필요하다.

상위: [무기 모듈](index.md)
