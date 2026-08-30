# Bomb

| 항목 | 값 |
|------|-----|
| 씬 | `enemies/bomb_enemy.tscn` |
| HP | 160 |
| 점수 | 20 |
| 최소 Threat | 1 |
| 비주얼 | `enemy_bomb.svg` |
| 투사체 | 없음 |

## 근접 자폭 (`BombProximityFuseComponent`)

- 플레이어가 `trigger_radius`(60) 안이면 정지 → **3초간 빨간 점멸 3회** → 자폭
- 편대 소속이면 기폭 시작 시 편대 중심 이동을 멈추고 Bomb를 detach한 뒤 무장
- 신관 무장과 적색 점멸이 시작되면 반투명 범위 프리뷰 표시
- 폭발 판정·VFX 최대 링·범위 프리뷰 반경은 모두 `base_explosion_radius(40) * 1.5 = 60px`
- `blast_damage` **1** (플레이어 피격은 이벤트당 항상 1)
- 폭발 반경 안의 **다른 적**은 hurtbox 겹침 시 즉시 처치(실드·HP 무시, 본인 제외). 점수·XP는 일반 `no_health` 경로
- `고속 기폭 장치` 적 증강 활성 시 무장 시간 `2.0초 / 1.5 ≈ 1.33초` (`target_spawn_id` 없음 → 모든 Bomb)

## 조합

- **Bomb 단독 Encounter는 없다.**
- 풀 등록: `bomb_drone_diamond` — [Diamond5](#formations/diamond-5) 중앙 Bomb + Drone 호위
- 레거시 `bomb_single` / `tanker_bomb_*`는 풀 미등록

→ [Encounter 카탈로그](#encounters/catalog)
