# 무기 STATUS 호버 포커스

## 목표

함선 시설처럼 장착 베이 헥스에 **호버만** 해도 하단 무기 디테일이 바뀌게 한다.

## AC

- [x] 호버/클릭 모두 베이 포커스
- [x] 포커스 전환 시 베이 행 재빌드 없음
- [x] ShipPanel 호버 동작과 체감 일치

## 구현

- `WeaponCoreCluster.core_hovered` + `WeaponLoadoutHud` 스타일 인플레이스 갱신
- 2026-08-05 실제 Gameplay 풀 기준 무기·플레이어 증강·적 증강 목록을 `docs/spec/`에 동기화
- 2026-08-05 `feature/weapon-status-hover` → main (검증 대기)
- 같은 브랜치: 궤도 방벽 HP 제거·탄막 소멸·적 접촉 피해
