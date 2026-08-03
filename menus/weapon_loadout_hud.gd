class_name WeaponLoadoutHud
extends VBoxContainer

## STATUS weapon panel:
## 장착 베이 — equal-size hexes in a horizontal row (click to focus),
## then 선택된 무기 | 장착된 모듈 side-by-side.

const HEX_MODULE_SCENE := preload("res://menus/hex_module_frame.tscn")
const MODULE_SLOT_COUNT := 4
const BAY_SLOT := 40.0
const MODULE_HEX := 12.0
const SELECTED_HEX := 28.0
const ROMAN := ["", "I", "II", "III", "IV", "V"]

@export var ship: Node2D

@onready var bay_title: Label = %BayTitle
@onready var bay_subtitle: Label = get_node_or_null("%BaySubtitle") as Label
@onready var bay_row: HBoxContainer = %BayRow
@onready var selected_title: Label = %SelectedWeaponTitle
@onready var selected_icon: TextureRect = %SelectedWeaponIcon
@onready var selected_name: Label = %SelectedWeaponName
@onready var modules_title: Label = %EquippedModulesTitle
@onready var modules_grid: GridContainer = %ModulesGrid
@onready var detail_footer: Label = %WeaponDetailFooter
@onready var trait_detail: Label = %TraitDetail

var _bay_clusters: Array[WeaponCoreCluster] = []
var _bay_index_by_cluster: Dictionary = {}
var _focused_bay_index := -1
var _focused_weapon_id: StringName = &""
var _focused_trait_id: StringName = &""
var _selected_hex: HexModuleFrame


func _ready() -> void:
	if ship == null:
		return
	var loadout := _get_loadout()
	if loadout == null:
		return
	add_theme_constant_override("separation", 2)
	if bay_title != null:
		bay_title.text = "무기 모듈"
	if bay_subtitle != null:
		bay_subtitle.text = "장착 베이"
	if bay_row != null:
		bay_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bay_row.add_theme_constant_override("separation", 8)
		bay_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bay_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if modules_grid != null:
		modules_grid.columns = 2
		modules_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modules_grid.add_theme_constant_override("h_separation", 3)
		modules_grid.add_theme_constant_override("v_separation", 3)
	if trait_detail != null:
		trait_detail.visible = false
		trait_detail.custom_minimum_size = Vector2.ZERO
	_ensure_selected_hex()
	loadout.loadout_changed.connect(refresh)
	call_deferred("refresh")


func _ensure_selected_hex() -> void:
	if _selected_hex != null or selected_icon == null:
		return
	var parent := selected_icon.get_parent()
	if parent == null:
		return
	selected_icon.visible = false
	_selected_hex = HEX_MODULE_SCENE.instantiate() as HexModuleFrame
	_selected_hex.apply_fixed_size(SELECTED_HEX)
	_selected_hex.interactive = false
	_selected_hex.border_width = 1.25
	_selected_hex.border_color = Color(0.45, 0.9, 1.0, 0.95)
	_selected_hex.fill_color = Color(0.05, 0.16, 0.28, 0.95)
	parent.add_child(_selected_hex)
	parent.move_child(_selected_hex, selected_icon.get_index())


func refresh() -> void:
	var loadout := _get_loadout()
	if loadout == null:
		_clear_container(bay_row)
		_bay_clusters.clear()
		_bay_index_by_cluster.clear()
		_focused_bay_index = -1
		_focused_weapon_id = &""
		_show_empty_detail()
		return
	_ensure_valid_focus(loadout)
	_rebuild_bays(loadout)
	_refresh_detail(loadout)


func _rebuild_bays(loadout: PlayerWeaponLoadout) -> void:
	_clear_container(bay_row)
	_bay_clusters.clear()
	_bay_index_by_cluster.clear()

	var count := loadout.get_max_equipped_weapon_count()
	if _focused_bay_index < 0 or _focused_bay_index >= count:
		_ensure_valid_focus(loadout)

	# Equal-size bay hexes in a horizontal row (empty slots keep outline).
	for index in count:
		var cluster := _make_cluster(index)
		cluster.apply_slot_size(BAY_SLOT, false)
		bay_row.add_child(cluster)
		_bay_clusters.append(cluster)
		_bind_cluster(cluster, loadout, index, index == _focused_bay_index)


func _make_cluster(bay_index: int) -> WeaponCoreCluster:
	var cluster := WeaponCoreCluster.new()
	_bay_index_by_cluster[cluster] = bay_index
	cluster.core_selected.connect(func(weapon_id: StringName, _is_record: bool) -> void:
		_focus_bay(bay_index, weapon_id, &"")
	)
	cluster.trait_selected.connect(func(weapon_id: StringName, trait_id: StringName, _is_record: bool) -> void:
		_focused_trait_id = trait_id
		_focus_bay(bay_index, weapon_id, trait_id)
	)
	return cluster


func _bind_cluster(
	cluster: WeaponCoreCluster,
	loadout: PlayerWeaponLoadout,
	index: int,
	focused: bool,
) -> void:
	var bay := loadout.get_bay(index)
	if bay == null or bay.is_empty():
		cluster.bind_weapon(&"", null, 1, {}, {}, {}, false, false, false)
		cluster.set_focused(false)
		return
	# Traits live in the module grid below — bay row stays equal-sized hexes only.
	cluster.bind_weapon(
		bay.equipped_weapon_id,
		loadout.get_weapon_icon(bay.equipped_weapon_id),
		loadout.get_weapon_level(bay.equipped_weapon_id),
		{},
		{},
		{},
		false,
		true,
		false,
	)
	cluster.set_focused(focused)


func _focus_bay(bay_index: int, weapon_id: StringName, trait_id: StringName) -> void:
	var loadout := _get_loadout()
	if loadout == null:
		return
	var bay := loadout.get_bay(bay_index)
	if bay == null or bay.is_empty():
		return
	var same := _focused_bay_index == bay_index and _focused_weapon_id == (
		bay.equipped_weapon_id if weapon_id == &"" else weapon_id
	)
	_focused_bay_index = bay_index
	_focused_weapon_id = bay.equipped_weapon_id if weapon_id == &"" else weapon_id
	_focused_trait_id = trait_id
	if not same:
		call_deferred("_rebuild_bays", loadout)
		call_deferred("_refresh_detail", loadout)
		return
	_refresh_detail(loadout)


func _ensure_valid_focus(loadout: PlayerWeaponLoadout) -> void:
	if _focused_bay_index >= 0:
		var bay := loadout.get_bay(_focused_bay_index)
		if bay != null and not bay.is_empty():
			_focused_weapon_id = bay.equipped_weapon_id
			return
	_focused_bay_index = -1
	_focused_weapon_id = &""
	_focused_trait_id = &""
	for index in loadout.get_max_equipped_weapon_count():
		var bay := loadout.get_bay(index)
		if bay != null and not bay.is_empty():
			_focused_bay_index = index
			_focused_weapon_id = bay.equipped_weapon_id
			return


func _refresh_detail(loadout: PlayerWeaponLoadout) -> void:
	if _focused_weapon_id == &"":
		_show_empty_detail()
		return
	if selected_title != null:
		selected_title.visible = true
	if modules_title != null:
		modules_title.visible = true
	if detail_footer != null:
		detail_footer.visible = true
		detail_footer.text = "모듈은 무기의 성능을 강화합니다."
	_ensure_selected_hex()
	var icon := loadout.get_weapon_icon(_focused_weapon_id)
	if _selected_hex != null:
		_selected_hex.visible = true
		_selected_hex.set_module_icon(icon)
		_selected_hex.set_module_text("", "")
	if selected_icon != null:
		selected_icon.visible = false
	if selected_name != null:
		selected_name.text = "%s Lv.%d" % [
			loadout.get_weapon_display_name(_focused_weapon_id),
			loadout.get_weapon_level(_focused_weapon_id),
		]
	_rebuild_module_cards(loadout)
	if trait_detail != null:
		trait_detail.visible = false
		trait_detail.text = ""


func _show_empty_detail() -> void:
	_ensure_selected_hex()
	if _selected_hex != null:
		_selected_hex.set_module_icon(null)
		_selected_hex.set_module_text("", "")
	if selected_icon != null:
		selected_icon.visible = false
	if selected_name != null:
		selected_name.text = "무기를 선택하세요"
	_clear_container(modules_grid)
	_add_empty_module_placeholders()
	if trait_detail != null:
		trait_detail.text = ""
		trait_detail.visible = false


func _rebuild_module_cards(loadout: PlayerWeaponLoadout) -> void:
	_clear_container(modules_grid)
	var traits := loadout.get_weapon_traits(_focused_weapon_id)
	var ids: Array[StringName] = []
	for key in traits.keys():
		if int(traits[key]) > 0:
			ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for trait_id in ids:
		modules_grid.add_child(_make_module_card(
			loadout.get_trait_display_name(trait_id),
			int(traits[trait_id]),
			loadout.get_trait_icon(trait_id),
			trait_id,
			false,
		))
	_add_empty_module_placeholders()


func _add_empty_module_placeholders() -> void:
	while modules_grid != null and modules_grid.get_child_count() < MODULE_SLOT_COUNT:
		modules_grid.add_child(_make_module_card("빈 슬롯", 0, null, &"", true))


func _make_module_card(
	label_text: String,
	rank: int,
	icon: Texture2D,
	trait_id: StringName,
	empty: bool,
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.1, 0.18, 0.92) if not empty else Color(0.02, 0.06, 0.1, 0.4)
	style.border_color = Color(0.3, 0.8, 1.0, 0.85) if not empty else Color(0.18, 0.4, 0.55, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)

	var hex := HEX_MODULE_SCENE.instantiate() as HexModuleFrame
	hex.apply_fixed_size(MODULE_HEX)
	hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hex.border_width = 1.0
	hex.interactive = not empty
	if empty:
		hex.set_module_text("", "")
		hex.set_module_icon(null)
		hex.border_color = Color(0.3, 0.55, 0.75, 0.5)
		hex.fill_color = Color(0.02, 0.06, 0.12, 0.2)
	else:
		hex.set_module_text("", "")
		hex.set_module_icon(icon)
		hex.border_color = Color(0.5, 0.92, 1.0, 0.95)
		hex.fill_color = Color(0.06, 0.18, 0.3, 0.95)
	row.add_child(hex)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size = Vector2(1, 0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if empty:
		label.text = "빈 슬롯 -"
		label.modulate = Color(0.55, 0.7, 0.8, 0.65)
	else:
		label.text = "%s %s" % [label_text, _rank_roman(rank)]
		label.modulate = Color(0.88, 0.96, 1.0, 1.0)
	row.add_child(label)

	if not empty and trait_id != &"":
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var select := func() -> void:
			_focused_trait_id = trait_id
		hex.module_hovered.connect(select)
		hex.module_clicked.connect(select)
		panel.mouse_entered.connect(select)
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _rank_roman(rank: int) -> String:
	return ROMAN[clampi(rank, 0, ROMAN.size() - 1)]


func _clear_container(container: Node) -> void:
	if container == null:
		return
	while container.get_child_count() > 0:
		var child := container.get_child(0)
		container.remove_child(child)
		child.free()


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null
