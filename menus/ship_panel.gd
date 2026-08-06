class_name ShipPanel
extends Control

@export var facility_registry: PlayerAugmentRegistry

@onready var detail_label: Label = %FacilityDetail
@onready var slot_rack: UniversalModuleSlotRack = %UniversalSlotRack

var _highlighted_tag: StringName = &""
var _hovered_slot := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	slot_rack.slot_hovered.connect(_on_slot_hovered)
	slot_rack.slot_hover_exited.connect(_on_slot_hover_exited)
	if facility_registry == null:
		_show_missing_registry()
		return
	_bind_registry_signal()
	call_deferred("refresh")


func refresh() -> void:
	if facility_registry == null:
		return
	slot_rack.set_registry(facility_registry)
	slot_rack.set_slots(facility_registry.get_module_slots())
	slot_rack.set_highlighted_tag(_highlighted_tag)
	if _hovered_slot >= facility_registry.get_slot_capacity():
		_hovered_slot = -1
	if _hovered_slot >= 0:
		_refresh_slot_detail(_hovered_slot)
	else:
		_refresh_summary()


func set_registry(registry: PlayerAugmentRegistry) -> void:
	if facility_registry != null and facility_registry.augments_changed.is_connected(refresh):
		facility_registry.augments_changed.disconnect(refresh)
	facility_registry = registry
	_bind_registry_signal()
	refresh()


func set_highlighted_facility(facility_id: StringName) -> void:
	_highlighted_tag = facility_id
	if slot_rack != null:
		slot_rack.set_highlighted_tag(facility_id)


func get_selected_facility_id() -> StringName:
	return _highlighted_tag


func set_expansion_preview(enabled: bool) -> void:
	if slot_rack != null:
		slot_rack.set_expansion_preview(enabled)


func get_detail_text() -> String:
	return detail_label.text if detail_label != null else ""


func _refresh_summary() -> void:
	var installed := facility_registry.get_installed_count()
	var capacity := facility_registry.get_slot_capacity()
	detail_label.text = "범용 슬롯 %d/%d · 빈 슬롯 %d" % [
		installed,
		capacity,
		capacity - installed,
	]


func _refresh_slot_detail(slot_index: int) -> void:
	var slots := facility_registry.get_module_slots()
	if slot_index < 0 or slot_index >= slots.size():
		_refresh_summary()
		return
	var state := slots[slot_index] as PlayerAugmentModuleState
	if state == null:
		detail_label.text = "슬롯 %d · 빈 슬롯" % (slot_index + 1)
		return
	var tag_name := String(state.augment.get_primary_module_tag())
	var definition := facility_registry.get_facility_definition(state.augment.get_primary_module_tag())
	if definition != null:
		tag_name = definition.display_name
	detail_label.text = "슬롯 %d · %s · %s" % [
		slot_index + 1,
		tag_name,
		state.augment.display_name,
	]


func _show_missing_registry() -> void:
	if slot_rack != null:
		slot_rack.set_registry(null)
		slot_rack.set_slots([])
	if detail_label != null:
		detail_label.text = "모듈 슬롯 데이터 없음"


func _bind_registry_signal() -> void:
	if facility_registry != null and not facility_registry.augments_changed.is_connected(refresh):
		facility_registry.augments_changed.connect(refresh)


func _on_slot_hovered(slot_index: int) -> void:
	_hovered_slot = slot_index
	_refresh_slot_detail(slot_index)


func _on_slot_hover_exited() -> void:
	_hovered_slot = -1
	if facility_registry != null:
		_refresh_summary()
