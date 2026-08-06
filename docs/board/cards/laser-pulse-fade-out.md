# 레이저 펄스 페이드아웃

`laser_pulse` OFF 전환 시 빔이 즉시 사라지지 않고 짧게 알파 페이드아웃한다.

## 목표

- OFF 시작과 함께 피해는 즉시 중단
- 비주얼은 `fade_out_duration`(기본 0.12초) 동안 알파 감소
- ON 복귀 시 짧은 페이드인(기본 0.05초)

## AC

- [x] OFF 순간 `visible` 토글 대신 알파 페이드
- [x] 피해 게이트는 기존 `_pulse_on` 유지
- [x] trait params / 현황 스펙 반영

## 구현

- 2026-08-06 feature/laser-pulse-fade-out → main (검증 대기)
