# 적 기획

각 적이 **왜 있는지**, 플레이어에게 **어떤 판단을 요구하는지**를 적는다.  
왼쪽 네비로 타입별 문서에 들어가고, 수치·사격·Encounter는 **구현 스펙**으로 이어진다.

| 적 | 한 줄 요약 | 기획 | 구현 |
|----|------------|------|------|
| [Drone](drone.md) | 편대 밀도 · 기본 탄압 | [의도 문서](drone.md) | [spec](../spec/#enemies/drone) |
| [Striker](striker.md) | 호위 편대의 핵 · 끊으면 판이 바뀜 | [의도 문서](striker.md) | [spec](../spec/#enemies/striker) |
| [Awl](awl.md) | 예고 후 돌진 · 몸박 | [의도 문서](awl.md) | [spec](../spec/#enemies/awl) |
| [Bomb](bomb.md) | 접근할수록 위험한 공간 압박 | [의도 문서](bomb.md) | [spec](../spec/#enemies/bomb) |
| [Interceptor](interceptor.md) | 측면 고속 통과 · 짧은 교전 | [의도 문서](interceptor.md) | [spec](../spec/#enemies/interceptor) |
| [Caster](caster.md) | 상단 탄막으로 아래 공간을 조임 | [의도 문서](caster.md) | [spec](../spec/#enemies/caster) |
| [Sniper](sniper.md) | 조준선으로 자리를 버리게 함 | [의도 문서](sniper.md) | [spec](../spec/#enemies/sniper) |
| [Elite](elite-fighter.md) | Threat 관문 · 처치 후 적 강화 | [의도 문서](elite-fighter.md) | [spec](../spec/#enemies/elite-fighter) |

조합·풀 가중치: [Encounter 카탈로그](../spec/#encounters/catalog) · 언제 뽑히는지: [런·페이싱](../spec/#run-pacing)

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-08-30 | 타입별 본문·인덱스 한국어 정리 |
| 2026-08-30 | 타입 링크를 상대 MD로 · 구 JS 캐시 시 vision 폴백 완화 |
| 2026-08-30 | 타입별 기획 MD + 네비 · 로스터에 충분한 설명 링크 |
| 2026-08-30 | 로스터 표 |
