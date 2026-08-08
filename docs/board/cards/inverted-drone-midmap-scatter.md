# Inverted 드론 midmap 산개

## 목표

`inverted_v3` / `v5` / `v7` 랩 프리셋도 일반 V/X와 같이 midmap 진입 후 외향 2.5배속 산개.

## AC

- `drone_midmap_entry` + `SEQUENCE_FINISHED` break
- `individual_scatter_double` (150px/s)
- 스펙·formation_encounter_pool 스모크에 inverted 포함

## 구현

- 2026-08-09 `feature/diamond-formation-sizes` → main (검증 대기)
