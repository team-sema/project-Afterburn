# Sniper 저격 적기

원거리 포지션을 한 번 확보한 뒤, 살아 있는 동안 **조준 → 레이저 → 쿨다운**을 반복하는 Threat 3 적.

## 상태 흐름

```text
ENTRY → POSITIONING → (AIMING → FIRING → COOLDOWN) × N
```

- **ENTRY / POSITIONING:** `tanker_guard_sniper` 편대는 `tanker_guard_entry_hold`로 상단(y=48) 도달 후 Hold. 편대 멤버 Sniper는 슬롯에 탄 채 AIMING.
- **AIMING (4.0s):** 매 프레임 플레이어 지속 추적. 빨간 반투명 Cone이 `start_angle → end_angle`로 축소. 데미지 없음.
- **FIRING (0.5s):** AIMING 마지막 방향으로 월드 고정 레이저 생성. 잔상·판정 0.5초 후 제거.
- **COOLDOWN (2.5s):** 포지션 유지, Cone/레이저/데미지 없음 → 다시 AIMING.

재발사 시 **재포지셔닝하지 않는다.** FormationController에 적 이름을 하드코딩하지 않는다.

## 수치 (export)

| 키 | 기본 |
|---|---|
| `aim_duration` | 4.0 |
| `laser_duration` | 0.5 |
| `cooldown_duration` | 2.5 |
| `telegraph_start_angle` | 42° (반각) |
| `telegraph_end_angle` | 1.2° |
| `laser_width` | 4 |
| `laser_range` | 480 |
| `laser_damage` | 1 |

## 구성

| 요소 | 역할 |
|---|---|
| `enemies/sniper_enemy.tscn` · `.gd` | 씬 · 스크립트 |
| `SniperAttackComponent` | 전투 상태 머신 |
| `SniperAimCone` | 조준 텔레그래프 |
| `SniperLaserBeam` | 월드 고정 레이저 공격 객체 |
| `HoldPositionMovementStep` | POSITIONING 이후 위치 고정 |
| `tanker_guard_sniper` Encounter | Threat 2–3 풀 등록 (전방 Tanker + 후방 Sniper) |

## 조준·발사 일치

발사 방향은 AIMING 종료 프레임의 `direction_to(player)`를 그대로 쓴다. 레이저는 플레이어/스나이퍼를 따라가지 않는다.

---

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-08 | 조준 Cone에서 중심선 제거 · 발사 레이저를 기체 원점에서 시작 |
| 2026-08-08 | Cone을 BombBlastPreview식 씬 자식 + 탄환 additive 스프라이트로 재구현 |
| 2026-08-08 | Cone을 Polygon2D/Line2D + gameplay_world 부모로 수정 (미표시 수정) |
| 2026-08-08 | 초안 · 지속 추적 · 반복 저격 확정 |
