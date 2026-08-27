# bomb-formation-escorts tasks

- [x] `bomb_drone_diamond` (중앙 Bomb + Drone 4기)
- [x] `bomb_drone_approach` — 플레이어 호밍 하강
- [x] Pool에서 `bomb_single`·Tanker Bomb 편대 제거 · Bomb는 Drone 다이아몬드만
- [x] fast fuse spawn-id 게이트 제거 · 기폭 시 편대 정지/detach
- [x] 폭발 반경 내 다른 적 즉시 처치
- [x] docs/spec · smoke 동기화

## AC 검증

1. enemy_threat / formation_encounter_pool / encounter_spawner / augment_policy / bomb_proximity_fuse PASS
2. bomb_drone_diamond uses `bomb_drone_approach`
3. 기폭 시 반경 안 적 처치 · 바깥 적 유지
4. Pool에 bomb_drone_diamond만 Bomb Encounter로 등록
