class_name BackdropTheme
extends Resource

## 배경 디테일 데이터 (docs/design/effects.md 「World」). `SpaceBackground`가 읽어
## 성운 색 면·소행성 실루엣·행성 윤곽 레이어를 만든다. 위치는 뷰포트 비율(0~1),
## 반지름·크기는 px다. 스테이지 테마가 생기면 Phase별로 이 리소스를 바꿔 끼운다.

## 순수 검정을 들어 올리는 바탕색. 알파가 덮는 정도다.
@export var base_tint := Color(0.05, 0.045, 0.14, 0.55)

@export_group("Nebula")
## 성운 색 면의 중심(뷰포트 비율). radii·colors와 같은 길이여야 한다.
@export var nebula_positions: PackedVector2Array = PackedVector2Array()
@export var nebula_radii: PackedFloat32Array = PackedFloat32Array()
@export var nebula_colors: PackedColorArray = PackedColorArray()
## px/s at speed_scale 1. 우주층(12)보다 느려 가장 먼 배경으로 읽힌다.
@export var nebula_speed := 6.0

@export_group("Rocks")
## 검은 소행성 실루엣의 중심(뷰포트 비율)과 반지름(px).
@export var rock_positions: PackedVector2Array = PackedVector2Array()
@export var rock_sizes: PackedFloat32Array = PackedFloat32Array()
@export var rock_color := Color(0.015, 0.012, 0.035, 0.96)
## px/s at speed_scale 1. 우주층과 먼 별층 사이.
@export var rock_speed := 26.0

@export_group("Planet")
## 0이면 행성을 그리지 않는다.
@export var planet_radius := 40.0
@export var planet_position := Vector2(0.8, 0.3)
@export var planet_color := Color(0.02, 0.015, 0.05, 1.0)
@export var planet_ring_color := Color(0.6, 0.35, 0.8, 0.35)


func nebula_count() -> int:
	return mini(nebula_positions.size(), mini(nebula_radii.size(), nebula_colors.size()))


func rock_count() -> int:
	return mini(rock_positions.size(), rock_sizes.size())
