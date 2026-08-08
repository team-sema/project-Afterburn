extends SceneTree

const LAYOUT_PATHS := [
	"res://formations/layouts/horizontal_formation.tscn",
	"res://formations/layouts/vertical_formation.tscn",
	"res://formations/layouts/v3_formation.tscn",
	"res://formations/layouts/v5_formation.tscn",
	"res://formations/layouts/v7_formation.tscn",
	"res://formations/layouts/v9_formation.tscn",
	"res://formations/layouts/inverted_v3_formation.tscn",
	"res://formations/layouts/inverted_v5_formation.tscn",
	"res://formations/layouts/inverted_v7_formation.tscn",
	"res://formations/layouts/diamond_formation.tscn",
	"res://formations/layouts/diamond_formation_13.tscn",
	"res://formations/layouts/x5_formation.tscn",
	"res://formations/layouts/x9_formation.tscn",
	"res://formations/layouts/triangle6_formation.tscn",
]

const EXPECTED_POSITIONS := {
	"res://formations/layouts/horizontal_formation.tscn": [
		Vector2(-48, 0), Vector2(-24, 0), Vector2(0, 0), Vector2(24, 0), Vector2(48, 0),
	],
	"res://formations/layouts/vertical_formation.tscn": [
		Vector2(0, -64), Vector2(0, -32), Vector2(0, 0), Vector2(0, 32), Vector2(0, 64),
	],
	"res://formations/layouts/v3_formation.tscn": [
		Vector2(0, 11), Vector2(-16, -11), Vector2(16, -11),
	],
	"res://formations/layouts/v5_formation.tscn": [
		Vector2(0, 11), Vector2(-16, -11), Vector2(16, -11),
		Vector2(-32, -33), Vector2(32, -33),
	],
	"res://formations/layouts/v7_formation.tscn": [
		Vector2(0, 11), Vector2(-16, -11), Vector2(16, -11),
		Vector2(-32, -33), Vector2(32, -33),
		Vector2(-48, -55), Vector2(48, -55),
	],
	"res://formations/layouts/v9_formation.tscn": [
		Vector2(0, 11), Vector2(-16, -11), Vector2(16, -11),
		Vector2(-32, -33), Vector2(32, -33),
		Vector2(-48, -55), Vector2(48, -55),
		Vector2(-64, -77), Vector2(64, -77),
	],
	"res://formations/layouts/inverted_v3_formation.tscn": [
		Vector2(-16, 22), Vector2(0, 0), Vector2(16, 22),
	],
	"res://formations/layouts/inverted_v5_formation.tscn": [
		Vector2(-32, 44), Vector2(-16, 22), Vector2(0, 0),
		Vector2(16, 22), Vector2(32, 44),
	],
	"res://formations/layouts/inverted_v7_formation.tscn": [
		Vector2(-48, 66), Vector2(-32, 44), Vector2(-16, 22), Vector2(0, 0),
		Vector2(16, 22), Vector2(32, 44), Vector2(48, 66),
	],
	"res://formations/layouts/diamond_formation.tscn": [
		Vector2(0, -28), Vector2(-32, 0), Vector2(0, 0),
		Vector2(32, 0), Vector2(0, 28),
	],
	"res://formations/layouts/diamond_formation_13.tscn": [
		Vector2(0, -40),
		Vector2(-20, -20), Vector2(0, -20), Vector2(20, -20),
		Vector2(-40, 0), Vector2(-20, 0), Vector2(0, 0), Vector2(20, 0), Vector2(40, 0),
		Vector2(-20, 20), Vector2(0, 20), Vector2(20, 20),
		Vector2(0, 40),
	],
	"res://formations/layouts/x5_formation.tscn": [
		Vector2(0, 0), Vector2(-16, -16), Vector2(16, -16),
		Vector2(-16, 16), Vector2(16, 16),
	],
	"res://formations/layouts/x9_formation.tscn": [
		Vector2(0, 0), Vector2(-16, -16), Vector2(16, -16),
		Vector2(-32, -32), Vector2(32, -32),
		Vector2(-16, 16), Vector2(16, 16),
		Vector2(-32, 32), Vector2(32, 32),
	],
	"res://formations/layouts/triangle6_formation.tscn": [
		Vector2(0, 10), Vector2(-12, -11), Vector2(12, -11),
		Vector2(-24, -32), Vector2(24, -32), Vector2(0, -32),
	],
}

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_authored_layouts()
	_test_explicit_sort_and_lookup()
	_test_duplicate_and_negative_validation()
	_test_position_repack_round_trip()

	if failures.is_empty():
		print("formation_layout_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("formation_layout_smoke_test: %s" % failure)
	quit(1)


func _test_authored_layouts() -> void:
	for path in LAYOUT_PATHS:
		var packed := load(path) as PackedScene
		_expect(packed != null, "%s loads as PackedScene" % path)
		if packed == null:
			continue
		var layout := packed.instantiate() as FormationLayout
		_expect(layout != null, "%s root is FormationLayout" % path)
		if layout == null:
			continue
		root.add_child(layout)
		_expect(layout.get_script().is_tool(), "%s layout preview script is editor-enabled" % path)
		_expect(
			not layout.is_processing(),
			"%s editor preview polling is disabled at runtime" % path,
		)
		var slots := layout.get_slots_sorted()
		var expected_positions: Array = EXPECTED_POSITIONS[path]
		_expect(
			slots.size() == expected_positions.size(),
			"%s contains its complete authored slot count" % path,
		)
		_expect(layout.validate_slots(), "%s passes slot validation" % path)
		_expect(
			layout.get_child_count() == expected_positions.size(),
			"%s has only direct slot children" % path,
		)
		for index in slots.size():
			var slot := slots[index]
			_expect(slot is Marker2D, "%s slot %d is Marker2D" % [path, index])
			_expect(slot.get_script().is_tool(), "%s slot preview script is editor-enabled" % path)
			_expect(slot.slot_index == index, "%s uses explicit ordered indices" % path)
			_expect(not slot.slot_id.is_empty(), "%s slot %d has an explicit id" % [path, index])
			_expect(slot.get_child_count() == 0, "%s slot %d has no runtime content" % [path, index])
			_expect(
				slot.position == expected_positions[index],
				"%s slot %d preserves its authored coordinate" % [path, index],
			)
		layout.free()


func _test_explicit_sort_and_lookup() -> void:
	var layout := FormationLayout.new()
	layout.name = "UnorderedLayout"
	root.add_child(layout)
	for index in [2, 0, 1]:
		var slot := FormationSlot.new()
		slot.name = "AuthoredSlot%d" % index
		slot.slot_index = index
		slot.slot_id = StringName("slot_%d" % index)
		layout.add_child(slot)

	var sorted := layout.get_slots_sorted()
	_expect(
		sorted.map(func(slot: FormationSlot) -> int: return slot.slot_index) == [0, 1, 2],
		"slot lookup sorts by explicit slot_index instead of child order",
	)
	_expect(layout.get_slot_by_index(1) == sorted[1], "get_slot_by_index returns the indexed slot")
	_expect(layout.get_slot(1) == sorted[1], "get_slot stable shorthand returns the indexed slot")
	_expect(layout.get_slot_by_id(&"slot_2") == sorted[2], "get_slot_by_id returns the named slot")
	layout.free()


func _test_duplicate_and_negative_validation() -> void:
	var layout := FormationLayout.new()
	layout.name = "InvalidLayout"
	root.add_child(layout)
	var indices := [-1, 3, 3]
	for index in indices:
		var slot := FormationSlot.new()
		slot.name = "Slot%s" % index
		slot.slot_index = index
		slot.slot_id = StringName("slot_%s" % index)
		layout.add_child(slot)

	var errors := layout.get_slot_validation_errors()
	_expect(not layout.validate_slots(), "invalid layout fails validation")
	_expect(_contains_text(errors, "negative"), "negative slot_index produces a warning")
	_expect(_contains_text(errors, "duplicate"), "duplicate slot_index produces a warning")
	_expect(_contains_text(errors, "duplicate slot_id"), "duplicate slot_id produces a warning")
	_expect(
		layout.get_configuration_warnings().size() == errors.size(),
		"editor configuration warnings expose validation errors",
	)
	var negative_slot := layout.get_slot(-1)
	_expect(
		_contains_text(negative_slot.get_configuration_warnings(), "zero or greater"),
		"FormationSlot exposes its negative-index configuration warning",
	)
	var duplicate_slot := layout.get_slot(3)
	_expect(
		_contains_text(duplicate_slot.get_configuration_warnings(), "slot_id"),
		"FormationSlot exposes its duplicate-id configuration warning",
	)
	layout.free()


func _test_position_repack_round_trip() -> void:
	var source := load(LAYOUT_PATHS[0]) as PackedScene
	var layout := source.instantiate() as FormationLayout
	root.add_child(layout)
	var authored_position := Vector2(-91.0, 17.0)
	layout.get_slot_by_index(0).position = authored_position

	var repacked := PackedScene.new()
	var pack_result := repacked.pack(layout)
	_expect(pack_result == OK, "edited layout can be packed")
	if pack_result == OK:
		var reopened := repacked.instantiate() as FormationLayout
		_expect(
			reopened.get_slot_by_index(0).position == authored_position,
			"directly dragged slot position survives scene packing",
		)
		reopened.free()
	layout.free()


func _contains_text(lines: PackedStringArray, needle: String) -> bool:
	for line in lines:
		if line.to_lower().contains(needle.to_lower()):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
