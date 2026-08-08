# Encounter Threat weight / difficulty

## 목표

Encounter에 `difficulty`를 두고, 풀에서는 `min_threat` + `weight = 60 / difficulty`로 등장 비율을 잡는다.

## AC 요약

- Preset `difficulty` (Interceptor pair 12 / trio 18 등)
- Entry `min_threat` (T1: drone/diamond/bomb/awl)
- 수동 `weights_by_threat` / `ThreatWeight` 제거
- `mixed_partial_diamond` 삭제

## 구현

- 2026-08-08 `feature/encounter-weight-array` → main (검증 대기)
