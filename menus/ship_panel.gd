class_name ShipPanel
extends Control

signal facility_selected(facility_id: StringName)

@export var facility_registry: PlayerAugmentRegistry
@export var selection_enabled := false

@onready var links: ShipFacilityLinks = %FacilityLinks
@onready var detail_label: Label = %FacilityDetail
@onready var detail_icon: TextureRect = %FacilityDetailIcon

var _modules: Array[ShipFacilityModule] = []
var _selected_facility_id: StringName = &""
var _expansion_preview_facility_id: StringName = &""
var _selection_input_enabled := false


func _ready() -> void:
	# Empty panel area must not steal mouse from the weapon UI below.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_collect_modules()
	resized.connect(_refresh_links)
	_refresh_links()
	if facility_registry == null:
		if not selection_enabled:
			push_warning("ShipPanel: no PlayerAugmentRegistry assigned; showing placeholders.")
		_show_missing_registry()
		return
	_bind_registry_signal()
	call_deferred("refresh")


func refresh() -> void:
	if facility_registry == null:
		return
	_ensure_default_selection()
	for module in _modules:
		_refresh_module(module)
	_refresh_detail()
	_refresh_links()


func _ensure_default_selection() -> void:
	# Mockup always shows a facility line (e.g. "엔진 : 빈 슬롯"), never blank prompt.
	if _selected_facility_id != &"":
		if facility_registry.get_facility_definition(_selected_facility_id) != null:
			return
	for module in _modules:
		if facility_registry.get_facility_definition(module.facility_id) != null:
			_selected_facility_id = module.facility_id
			return


func set_registry(registry: PlayerAugmentRegistry) -> void:
	if facility_registry != null and facility_registry.augments_changed.is_connected(refresh):
		facility_registry.augments_changed.disconnect(refresh)
	facility_registry = registry
	_bind_registry_signal()
	refresh()


func set_highlighted_facility(facility_id: StringName) -> void:
	_selected_facility_id = facility_id
	refresh()


func set_expansion_preview_facility(facility_id: StringName) -> void:
	_expansion_preview_facility_id = facility_id
	refresh()


func set_selection_input_enabled(enabled: bool) -> void:
	_selection_input_enabled = enabled
	refresh()


func get_facility_module(facility_id: StringName) -> ShipFacilityModule:
	for module in _modules:
		if module.facility_id == facility_id:
			return module
	return null


func get_selectable_modules() -> Array[ShipFacilityModule]:
	var selectable: Array[ShipFacilityModule] = []
	for module in _modules:
		if module.focus_mode == Control.FOCUS_ALL:
			selectable.append(module)
	return selectable


func select_facility(facility_id: StringName) -> void:
	set_highlighted_facility(facility_id)


func get_selected_facility_id() -> StringName:
	return _selected_facility_id


func get_detail_text() -> String:
	return detail_label.text if detail_label != null else ""


func _collect_modules() -> void:
	_modules.clear()
	for node in find_children("*", "", true, false):
		var module := node as ShipFacilityModule
		if module == null:
			continue
		if module.facility_id == &"":
			push_error("ShipPanel: facility module '%s' has no facility_id." % module.name)
			continue
		_modules.append(module)
		module.facility_clicked.connect(_on_facility_clicked)
		module.facility_hovered.connect(_on_facility_hovered)
		module.facility_focused.connect(_on_facility_focused)


func _refresh_links() -> void:
	if links != null:
		links.set_links(_modules, _selected_facility_id)


func _refresh_module(module: ShipFacilityModule) -> void:
	var definition := facility_registry.get_facility_definition(module.facility_id)
	if definition == null:
		module.show_unknown_facility()
		module.is_selected = false
		return
	module.update_state(
		definition.display_name,
		facility_registry.get_facility_slots(module.facility_id),
		definition.icon,
	)
	var can_select_expansion := (
		selection_enabled
		and _selection_input_enabled
		and facility_registry.can_expand_slots(module.facility_id)
	)
	module.set_selection_enabled(can_select_expansion)
	module.set_expansion_preview(
		can_select_expansion and module.facility_id == _expansion_preview_facility_id
	)
	module.is_selected = module.facility_id == _selected_facility_id


func _refresh_detail() -> void:
	if detail_label == null:
		return
	if detail_icon != null:
		detail_icon.texture = null
		detail_icon.visible = false
	var definition := facility_registry.get_facility_definition(_selected_facility_id)
	if definition == null:
		detail_label.text = ""
		return
	# Mockup: plain line under the facility grid — "엔진 : 빈 슬롯"
	var names: PackedStringArray = []
	for module in facility_registry.get_facility_slots(_selected_facility_id):
		if module == null:
			names.append("빈 슬롯")
		else:
			names.append((module as PlayerAugmentModuleState).augment.display_name)
	if names.is_empty():
		names.append("빈 슬롯")
	detail_label.text = "%s : %s" % [
		definition.display_name,
		" / ".join(names),
	]


func _show_missing_registry() -> void:
	for module in _modules:
		module.show_unknown_facility()
	if detail_label != null:
		detail_label.text = "시설 데이터 없음"


func _bind_registry_signal() -> void:
	if facility_registry != null and not facility_registry.augments_changed.is_connected(refresh):
		facility_registry.augments_changed.connect(refresh)


func _on_facility_clicked(facility_id: StringName) -> void:
	set_highlighted_facility(facility_id)
	if selection_enabled and _selection_input_enabled and facility_registry.can_expand_slots(facility_id):
		facility_selected.emit(facility_id)


func _on_facility_hovered(facility_id: StringName) -> void:
	set_highlighted_facility(facility_id)
	if selection_enabled and _selection_input_enabled:
		set_expansion_preview_facility(facility_id)


func _on_facility_focused(facility_id: StringName) -> void:
	if not selection_enabled or not _selection_input_enabled:
		return
	set_highlighted_facility(facility_id)
	set_expansion_preview_facility(facility_id)
