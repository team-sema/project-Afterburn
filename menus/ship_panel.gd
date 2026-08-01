class_name ShipPanel
extends Control

## 오른쪽 UI의 함선 상태 패널. 시설 레지스트리를 읽어 표시만 하고,
## 시설 레벨이나 플레이어 스탯은 직접 수정하지 않는다.

@export var facility_registry: ShipFacilityRegistry

@onready var links: ShipFacilityLinks = %FacilityLinks
@onready var detail_label: Label = %FacilityDetail
@onready var detail_icon: TextureRect = %FacilityDetailIcon

var _modules: Array[ShipFacilityModule] = []
var _selected_facility_id: StringName = &""


func _ready() -> void:
	_collect_modules()
	resized.connect(_refresh_links)
	_refresh_links()
	if facility_registry == null:
		push_warning("ShipPanel: no ShipFacilityRegistry assigned; showing placeholders.")
		_show_missing_registry()
		return
	if not facility_registry.facility_level_changed.is_connected(_on_facility_level_changed):
		facility_registry.facility_level_changed.connect(_on_facility_level_changed)
	# The registry lives in the gameplay subscene, so read levels after it is ready.
	call_deferred("refresh")


func refresh() -> void:
	if facility_registry == null:
		return
	if _selected_facility_id == &"" and not _modules.is_empty():
		_selected_facility_id = _modules[0].facility_id
	for module in _modules:
		_refresh_module(module)
	_refresh_detail()
	_refresh_links()


func select_facility(facility_id: StringName) -> void:
	if _selected_facility_id == facility_id:
		return
	_selected_facility_id = facility_id
	refresh()


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
		if not module.facility_clicked.is_connected(_on_facility_selected):
			module.facility_clicked.connect(_on_facility_selected)
		if not module.facility_hovered.is_connected(_on_facility_selected):
			module.facility_hovered.connect(_on_facility_selected)


func _refresh_links() -> void:
	if links != null:
		links.set_links(_modules, _selected_facility_id)


func _refresh_module(module: ShipFacilityModule) -> void:
	var definition := facility_registry.get_facility_definition(module.facility_id)
	if definition == null:
		module.show_unknown_facility()
		module.is_selected = false
		return
	var level := facility_registry.get_facility_level(module.facility_id)
	var effect_text := definition.format_value(
		facility_registry.get_facility_effect(module.facility_id)
	)
	module.update_state(
		definition.display_name,
		level,
		effect_text,
		_upgrade_state(module.facility_id),
		definition.icon,
	)
	module.is_selected = module.facility_id == _selected_facility_id


func _upgrade_state(facility_id: StringName) -> ShipFacilityModule.UpgradeState:
	if facility_registry.can_upgrade_facility(facility_id):
		return ShipFacilityModule.UpgradeState.UPGRADABLE
	if facility_registry.get_max_facility_level(facility_id) <= 1:
		return ShipFacilityModule.UpgradeState.UNSET
	return ShipFacilityModule.UpgradeState.MAXED


func _refresh_detail() -> void:
	if detail_label == null:
		return
	var definition := facility_registry.get_facility_definition(_selected_facility_id)
	if definition == null:
		detail_label.text = "시설을 선택하세요"
		if detail_icon != null:
			detail_icon.texture = null
		return
	if detail_icon != null:
		detail_icon.texture = definition.icon
	var level := facility_registry.get_facility_level(_selected_facility_id)
	var current_text := definition.format_value(
		facility_registry.get_facility_effect(_selected_facility_id)
	)
	var detail := "%s Lv.%d : %s\n현재 %s" % [
		definition.display_name,
		level,
		definition.effect_summary,
		current_text,
	]
	if facility_registry.can_upgrade_facility(_selected_facility_id):
		var next_text := definition.format_value(
			facility_registry.get_next_facility_effect(_selected_facility_id)
		)
		detail += " → Lv.%d %s" % [level + 1, next_text]
	elif definition.get_max_level() <= 1:
		detail += " (강화 수치 미설정)"
	else:
		detail += " (최대)"
	detail_label.text = detail


func _show_missing_registry() -> void:
	for module in _modules:
		module.show_unknown_facility()
	if detail_label != null:
		detail_label.text = "시설 데이터 없음"


func _on_facility_selected(facility_id: StringName) -> void:
	select_facility(facility_id)


func _on_facility_level_changed(_facility_id: StringName, _new_level: int) -> void:
	refresh()
