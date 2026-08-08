# bomb-formation-escorts tasks

- [x] `tanker_bomb_vertical` (`bomb_drone_diamond` · `tanker_bomb_horizontal` 삭제)
- [x] `tanker_bomb_approach` — 플레이어 호밍 하강
- [x] Pool에서 `bomb_single` 제거 · Bomb는 vertical 탱커만
- [x] fast fuse spawn-id 게이트 제거 · 기폭 시 편대 정지/detach
- [x] 폭발 반경 내 다른 적 즉시 처치
- [x] docs/spec · smoke 동기화

## AC 검증

1. enemy_threat / formation_encounter_pool / encounter_spawner / augment_policy / bomb_proximity_fuse PASS
2. tanker_bomb_vertical uses `tanker_bomb_approach`
3. 기폭 시 반경 안 적 처치 · 바깥 적 유지
4. Pool에 bomb_drone_diamond 없음
