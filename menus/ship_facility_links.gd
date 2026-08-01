class_name ShipFacilityLinks
extends Control

## 시설 칩과 함선 그림의 하드포인트를 잇는 배선만 그린다.
## 함선 그림 위·시설 칩 아래에 오도록 ShipPanel 안에서 순서로 배치한다.

const LINE_IDLE := Color(0.16, 0.55, 0.82, 0.55)
const LINE_ACTIVE := Color(0.55, 0.95, 1.0, 0.9)
const NODE_IDLE := Color(0.3, 0.72, 0.95, 0.8)
const NODE_ACTIVE := Color(0.8, 1.0, 1.0, 1.0)
const NODE_SIZE := 4.0

@export var ship_diagram: Control

var _modules: Array[ShipFacilityModule] = []
var _selected_facility_id: StringName = &""


func set_links(modules: Array[ShipFacilityModule], selected_facility_id: StringName) -> void:
	_modules = modules
	_selected_facility_id = selected_facility_id
	queue_redraw()


func _draw() -> void:
	if ship_diagram == null:
		return
	var ship_rect := Rect2(ship_diagram.position, ship_diagram.size)
	for module in _modules:
		if not is_instance_valid(module):
			continue
		var toward_left := module.position.x > ship_rect.position.x
		var start := module.get_connector_point(toward_left)
		var ship_edge_x := ship_rect.position.x + (ship_rect.size.x if toward_left else 0.0)
		var bend_x := (start.x + ship_edge_x) * 0.5
		var hardpoint := ship_rect.position + module.hardpoint * ship_rect.size
		var selected := module.facility_id == _selected_facility_id
		draw_polyline(
			PackedVector2Array([
				start,
				Vector2(bend_x, start.y),
				Vector2(bend_x, hardpoint.y),
				hardpoint,
			]),
			LINE_ACTIVE if selected else LINE_IDLE,
			1.0,
		)
		draw_rect(
			Rect2(hardpoint - Vector2(NODE_SIZE, NODE_SIZE) * 0.5, Vector2(NODE_SIZE, NODE_SIZE)),
			NODE_ACTIVE if selected else NODE_IDLE,
		)
