# Task: threat-monitor-lab-fit

## Canonical docs

- [scene-flow.md](../scene-flow.md) · [combat.md](../combat.md)

## Scope

- `threat_monitor/threat_monitor_lab.tscn`
- `tests/threat_monitor_smoke_test.gd`
- `docs/design/scene-flow.md` · `docs/design/combat.md`

## Work

1. 우측 Detail 패널 여백·간격이 406px로 640×360을 넘어 Layout이 잘리던 문제 수정.
2. smoke가 앵커 Control의 `get_combined_minimum_size()==0`만 보지 않고 Layout·SubViewport 실측으로 검증.

## Verification

- [x] `.\tools\run-godot.cmd --headless --script res://tests/threat_monitor_smoke_test.gd`
