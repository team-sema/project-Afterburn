# Sniper 저격 적기

원거리 포지션을 한 번 확보한 뒤, 살아 있는 동안 **조준 → 고속탄 → 쿨다운**을 반복하는 Threat 3 적.

## 상태 흐름

```text
ENTRY → POSITIONING → (AIMING → FIRING → COOLDOWN) × N
```

- **ENTRY / POSITIONING:** `tanker_guard_sniper` 편대는 `tanker_guard_entry_hold`로 상단(y=48) 도달 후 Hold. 편대 멤버 Sniper는 슬롯에 탄 채 AIMING.
- **AIMING (4.0s + 0.18s):** 매 프레임 플레이어 지속 추적. 옅은 적색 직선 2개가 cubic ease-out으로 빠르게 수렴한 뒤 0.18초간 완전 조준 상태를 유지. 수렴할수록 선이 진해지며 데미지는 없다.
- **FIRING (0.1s recovery):** 조준선을 숨기고 마지막 방향으로 900px/s 고속탄을 발사한다. 기체 `Anchor`는 반대 방향으로 5px 반동한 뒤 복귀한다.
- **COOLDOWN (2.5s):** 포지션 유지, 조준선 없음 → 다시 AIMING.

재발사 시 **재포지셔닝하지 않는다.** FormationController에 적 이름을 하드코딩하지 않는다.

## 수치 (export)

| 키 | 기본 |
|---|---|
| `aim_duration` | 4.0 |
| `focus_hold_duration` | 0.18 |
| `shot_recovery_duration` | 0.1 |
| `cooldown_duration` | 2.5 |
| `telegraph_start_angle` | 14° (반각) |
| `telegraph_end_angle` | 0.05° |
| `projectile_speed` | 900 |
| `projectile_width` | 3 |
| `projectile_range` | 480 |
| `projectile_damage` | 1 |
| `recoil_distance` | 5 |

## 구성

| 요소 | 역할 |
|---|---|
| `enemies/sniper_enemy.tscn` · `.gd` | 씬 · 스크립트 |
| `SniperAttackComponent` | 전투 상태 머신 |
| `SniperAimCone` | 수렴·명도 변화 이중선 조준 텔레그래프 |
| `SniperBullet` | 조준 경로를 따라 이동하는 고속 탄환 |
| `HoldPositionMovementStep` | POSITIONING 이후 위치 고정 |
| `tanker_guard_sniper` Encounter | Threat 2–3 풀 등록 (전방 Tanker + 후방 Sniper) |

## 조준·발사 일치

발사 방향은 완전 조준 유지가 끝나는 프레임의 `direction_to(player)`를 그대로 쓴다. 탄환은 발사 뒤 플레이어/스나이퍼를 따라가지 않는다.

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-09 | Cone·고정 레이저를 수렴 이중선·고속탄으로 교체하고 완전 조준 유지와 발사 반동 추가 |
| 2026-08-08 | 조준 Cone에서 중심선 제거 · 발사 레이저를 기체 원점에서 시작 |
| 2026-08-08 | Cone을 BombBlastPreview식 씬 자식 + 탄환 additive 스프라이트로 재구현 |
| 2026-08-08 | Cone을 Polygon2D/Line2D + gameplay_world 부모로 수정 (미표시 수정) |
| 2026-08-08 | 초안 · 지속 추적 · 반복 저격 확정 |
