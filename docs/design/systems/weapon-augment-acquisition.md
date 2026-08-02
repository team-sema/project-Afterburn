# Feature: 무기 증강 획득 · 필드 드롭 제거

## 목적

필드 무기 드롭을 제거하고, 무기 획득·레벨·특성·복원을 전부 레벨업 증강 선택으로 처리한다. 필드 성장 아이템은 경험치만 남긴다.

## 규칙

1. 적 `WeaponDropComponent`는 드롭하지 않는다(비활성). 필드 `WeaponPickup` 생성·획득 경로를 런에서 쓰지 않는다.
2. XP 드롭은 `ExperienceDropComponent.drop_chance`(데이터/익스포트)로만 조정. 적별 `experience_amount`는 유지.
3. 증강 Kind: `WEAPON_ACQUIRE` / `WEAPON_LEVEL` / `WEAPON_TRAIT` / `FACILITY_EFFECT` / `STAT_MULTIPLIER`. 가중치 `offer_weight`(데이터).
4. `WEAPON_ACQUIRE`: 미보유=신규 장착, 기록=복원(레벨+1 없음). 만석이면 증강 안 교체 UI.
5. `WEAPON_LEVEL`: 장착·기록 모두 대상, weapon_id 레벨 +1.
6. `WEAPON_TRAIT`: 장착 중 무기만, 시설 슬롯 소모 없음. 전투 효과는 기존 스캐폴드(상태·UI).
7. 레이더는 XP(및 기타 필드 픽업) 반경만. 증강 무기 확률에 영향 없음. 격납고 효과 미정 유지.
8. 무기 전용 증강은 함선 시설 모듈 슬롯을 소모하지 않는다.

## AC

- [x] 필드 무기 드롭·픽업·획득 UI/입력 없음
- [x] XP 드롭 빈도 데이터 기반 소폭 상향
- [x] 증강으로 신규/복원/레벨/특성/시설 선택 가능
- [x] 만석 시 증강 안 교체, 기록 보존
- [x] 스펙·스모크 통과

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-08-02 | 초안 |
| 2026-08-02 | 구현 완료 |
