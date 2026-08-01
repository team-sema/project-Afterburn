class_name NeonCornerFrame
extends Control

## 패널 모서리에 SF 브래킷을 그리는 장식 전용 오버레이. 입력·레이아웃에 관여하지 않는다.

@export var color := Color(0.2, 0.72, 1.0, 0.9)
@export var bracket_length := 12.0
@export var thickness := 2.0
## 패널 경계에서 안쪽으로 얼마나 들여 그릴지.
@export var inset := 4.0
## 좌우 세로변에 브래킷을 그릴지 (패널이 화면 가장자리에 붙은 쪽은 끌 수 있다).
@export var draw_left := true
@export var draw_right := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var half := thickness * 0.5
	var left := inset + half
	var top := inset + half
	var right := size.x - inset - half
	var bottom := size.y - inset - half
	var length := minf(bracket_length, minf(size.x, size.y) * 0.4)

	_draw_corner(Vector2(left, top), Vector2(1, 0), Vector2(0, 1), length, draw_left)
	_draw_corner(Vector2(right, top), Vector2(-1, 0), Vector2(0, 1), length, draw_right)
	_draw_corner(Vector2(left, bottom), Vector2(1, 0), Vector2(0, -1), length, draw_left)
	_draw_corner(Vector2(right, bottom), Vector2(-1, 0), Vector2(0, -1), length, draw_right)


func _draw_corner(
	corner: Vector2,
	horizontal: Vector2,
	vertical: Vector2,
	length: float,
	with_vertical: bool,
) -> void:
	draw_line(corner, corner + horizontal * length, color, thickness)
	if with_vertical:
		draw_line(corner, corner + vertical * length, color, thickness)
