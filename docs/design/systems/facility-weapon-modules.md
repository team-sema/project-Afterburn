# 시설 모듈 효과 (FacilityModuleEffect)

범용 시설 슬롯에 장착하는 모듈마다 `FacilityModuleEffect`를 두고, Kind별로 공통 스탯을 적용한다. 기존 시설 구분은 module tag로 유지한다. 무기 고유 trait 전투도 본 feature에서 구현한다.

## 목표

- 13종 시설 모듈이 풀에 등장하고 범용 슬롯에 장착된다.
- 동일 Kind 배율은 primary 곱, 가산은 합.
- 과충전(주기)·비상 출력(선체 피격)·엔진 부스터·실드 충전 속도·XP 배율 등 timed/특수 효과 동작.
- `facility_id = hangar` 유지, 표시명만 동력로.
- 무기별 `WEAPON_TRAIT` 28종이 풀에 등장하고 해당 `WeaponSystem`이 전투에 반영한다.

## 스택·타이밍

| 구분 | 규칙 |
|------|------|
| 배율 Kind | 장착 레벨 primary 곱 |
| 가산 Kind | primary 합 |
| timed (PERIODIC / HULL_HIT / ENGINE_BOOST) | 강도=primary 곱, duration·interval·cooldown=해당 Kind **첫 모듈** 값 |

## 모듈 요약

| id | 부위 | Kind | 수치 |
|----|------|------|------|
| facility_weapon_room | weapon_room | WEAPON_DAMAGE_MULT | 1.15 |
| facility_weapon_room_boss | weapon_room | BOSS_DAMAGE_MULT | 1.3 |
| facility_weapon_room_fire_rate | weapon_room | WEAPON_FIRE_RATE_MULT | 1.15 |
| facility_hangar | hangar | PERIODIC_DAMAGE_BUFF | 1.4 / 5s / 20s |
| facility_reactor_emergency | hangar | HULL_HIT_DAMAGE_BUFF | 1.3 / 5s / 15s CD |
| facility_engine | engine | MOVE_SPEED_MULT | 1.25 |
| facility_engine_boost | engine | ENGINE_BOOST | 2.5 / 0.8s / 7s CD |
| facility_hull | hull | MAX_HULL_ADD | +1 |
| facility_hull_iframe | hull | HULL_HIT_IFRAMES | +1.0s |
| facility_radar | radar | PICKUP_RANGE_MULT | 1.5 |
| facility_radar_xp | radar | XP_GAIN_MULT | 1.5 |
| facility_shield | shield | MAX_SHIELD_ADD | +1 |
| facility_shield_charge | shield | SHIELD_CHARGE_SPEED_MULT | 2.0 |

## 적용 경로

- `ShipFacilityApplier` — 상시 스탯
- `ShipCombatBuffController` — 과충전·비상 출력 → `PlayerWeaponLoadout.set_temp_damage_multiplier`
- `EngineBoostComponent` — `engine_boost`(Shift) → `PlayerAugmentApplier.set_boost_move_speed_multiplier`
- `HurtComponent` — 선체 피격 시 iframe + emergency notify
- `WeaponSystem.resolve_hit_damage` — 보스 배율 (hurtbox → Enemy.is_boss)

## 무기 Trait 전투

- `WeaponTraitDefinition.params`(Lv.I) + `rank_overrides`(Lv.II·III) + `WeaponSystem.get_trait_param`
- 동일 카드 반복 선택으로 Lv.I~III 성장, 최대 레벨이면 오퍼 후보에서 제외
- 무기 스크립트별 구현 (통일 인터페이스 없음)

| 무기 | trait | 요지 |
|------|-------|------|
| Blaster | rapid / sync / accel_ap / ricochet | 연사·동시발사·관통·도탄 |
| Laser | wide / heat / refract / pulse | 폭·열스택·굴절·펄스(오프 시 빔 페이드아웃) |
| Shotgun | expanded / choke / cut / burst | 펠릿·집탄·근거리·버스트 |
| Aux cannon | formation(`aux_heavy_barrel` 호환 ID) / auto / he / hv_ap | 드론 증설·연사·AOE·관통 + 옵션 드론 전방 사격 |
| Plasma | expand / cluster / field / gravity | 반경·클러스터·잔류장·흡인 |
| Missile | multi / mobility / proximity / terminal | 다발·탄속·AOE·비행시간 보너스 |
| Barrier | multi / fast / expand / repulse | 세그먼트·재타격 쿨·크기·넉백 |

구 `blaster_pierce` / `laser_fork` 카드는 제거. 방벽 기본 `segment_arc_length≈11.33`, 비주얼 Y 스케일 1/3.

## 비범위

- 보스 엔티티 신규 스폰 (플래그·그룹만)

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-06 | `laser_pulse` OFF 전환 시 빔 알파 페이드아웃 |
| 2026-08-06 | 무기 trait 28종 전투 구현 섹션 추가 |
| 2026-08-06 | 무기 모듈 Lv.I~III 및 무기실 공통 공속 모듈 추가 |
| 2026-08-06 | 초안 · 12모듈 FacilityModuleEffect 설계 |
