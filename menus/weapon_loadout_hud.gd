class_name WeaponLoadoutHud
extends VBoxContainer

## STATUS weapon panel.
## Runtime bay/module hexes are duplicated from editor Templates (see %HudTemplates).

const MODULE_SLOT_COUNT := 4
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
@onready var detail_rule: ColorRect = get_node_or_null("%DetailRule") as ColorRect
@onready var detail_footer: Label = %WeaponDetailFooter
@onready var trait_detail: Label = %TraitDetail
@onready var bay_slot_template: WeaponCoreCluster = %BaySlotTemplate
@onready var module_hex_template: HexModuleFrame = %ModuleHexTemplate
@onready var selected_weapon_hex: HexModuleFrame = %SelectedWeaponHex

var _bay_clusters: Array[WeaponCoreCluster] = []
var _bay_index_by_cluster: Dictionary = {}
var _focused_bay_index := -1
var _focused_weapon_id: StringName = &""
var _focused_trait_id: StringName = &""
var _selected_hex: HexModuleFrame
var _hover_trait_id: StringName = &""


func _ready() -> void:
	if ship == null:
		return
	var loadout := _get_loadout()
	if loadout == null:
		return
	add_theme_constant_override("separation", 4)
	if bay_title != null:
		bay_title.text = "무기 모듈"
	if bay_subtitle != null:
		bay_subtitle.visible = false
	if bay_row != null:
		bay_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bay_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bay_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_columns := get_node_or_null("%DetailColumns") as Control
	if detail_columns != null:
		detail_columns.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bay_spacer := get_node_or_null("%BayDetailSpacer") as Control
	if bay_spacer != null:
		bay_spacer.custom_minimum_size = Vector2(0, 8)
		bay_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bay_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if modules_grid != null:
		modules_grid.columns = 4
		modules_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if detail_rule != null:
		detail_rule.visible = true
		detail_rule.custom_minimum_size = Vector2(0, 1)
	if trait_detail != null:
		trait_detail.visible = false
		trait_detail.custom_minimum_size = Vector2.ZERO
	if detail_footer != null:
		detail_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_footer.clip_text = true
		detail_footer.max_lines_visible = 2
		detail_footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_prepare_templates()
	_ensure_selected_hex()
	loadout.loadout_changed.connect(refresh)
	call_deferred("refresh")


func _prepare_templates() -> void:
	if bay_slot_template != null:
		bay_slot_template.visible = false
		bay_slot_template.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if module_hex_template != null:
		module_hex_template.visible = false
		module_hex_template.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _weapon_hex_side() -> float:
	if bay_slot_template != null and bay_slot_template.custom_minimum_size.x > 0.0:
		return bay_slot_template.custom_minimum_size.x
	return 42.0


func _module_hex_side() -> float:
	if module_hex_template != null and module_hex_template.custom_minimum_size.x > 0.0:
		return module_hex_template.custom_minimum_size.x
	return 22.0


func _ensure_selected_hex() -> void:
	if selected_icon != null:
		selected_icon.visible = false
	_selected_hex = selected_weapon_hex
	if _selected_hex == null:
		return
	_selected_hex.visible = true
	_selected_hex.interactive = false
	_selected_hex.apply_fixed_size(_weapon_hex_side())
	_selected_hex.border_width = 1.25
	_selected_hex.border_color = Color(0.45, 0.9, 1.0, 0.95)
	_selected_hex.fill_color = Color(0.05, 0.16, 0.28, 0.95)


func refresh() -> void:
	var loadout := _get_loadout()
	if loadout == null:
		_clear_runtime_children(bay_row)
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
	_clear_runtime_children(bay_row)
	_bay_clusters.clear()
	_bay_index_by_cluster.clear()

	var count := loadout.get_max_equipped_weapon_count()
	if _focused_bay_index < 0 or _focused_bay_index >= count:
		_ensure_valid_focus(loadout)

	var side := _weapon_hex_side()
	for index in count:
		var cluster := _make_cluster(index)
		bay_row.add_child(cluster)
		cluster.apply_slot_size(side, false)
		_bay_clusters.append(cluster)
		_bind_cluster(cluster, loadout, index, index == _focused_bay_index)


func _make_cluster(bay_index: int) -> WeaponCoreCluster:
	assert(bay_slot_template != null, "WeaponLoadoutHud requires %BaySlotTemplate placeholder.")
	var cluster := bay_slot_template.duplicate() as WeaponCoreCluster
	cluster.visible = true
	cluster.mouse_filter = Control.MOUSE_FILTER_STOP
	cluster.name = "Bay_%d" % bay_index
	_bay_index_by_cluster[cluster] = bay_index
	var focus_core := func(weapon_id: StringName, _is_record: bool) -> void:
		_focus_bay(bay_index, weapon_id, &"")
	cluster.core_hovered.connect(focus_core)
	cluster.core_selected.connect(focus_core)
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
	_hover_trait_id = &""
	if not same:
		_apply_bay_focus_styles()
	_refresh_detail(loadout)


func _apply_bay_focus_styles() -> void:
	for index in _bay_clusters.size():
		_bay_clusters[index].set_focused(index == _focused_bay_index)


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
	if _hover_trait_id != &"":
		_show_trait_description(loadout, _hover_trait_id)
	else:
		_show_weapon_description(loadout)


func _show_empty_detail() -> void:
	_ensure_selected_hex()
	if _selected_hex != null:
		_selected_hex.set_module_icon(null)
		_selected_hex.set_module_text("", "")
	if selected_icon != null:
		selected_icon.visible = false
	if selected_name != null:
		selected_name.text = "무기를 선택하세요"
	_clear_runtime_children(modules_grid)
	_add_empty_module_placeholders()
	_hover_trait_id = &""
	_set_description("")


func _show_weapon_description(loadout: PlayerWeaponLoadout) -> void:
	var name := loadout.get_weapon_display_name(_focused_weapon_id)
	var level := loadout.get_weapon_level(_focused_weapon_id)
	var body := loadout.get_weapon_description(_focused_weapon_id)
	if body == "":
		_set_description("%s Lv.%d" % [name, level])
	else:
		_set_description("%s Lv.%d\n%s" % [name, level, body])


func _show_trait_description(loadout: PlayerWeaponLoadout, trait_id: StringName) -> void:
	var traits := loadout.get_weapon_traits(_focused_weapon_id)
	var rank := int(traits.get(trait_id, 0))
	var title := loadout.get_trait_display_name(trait_id)
	if rank > 0:
		title = "%s %s" % [title, _rank_roman(rank)]
	var body := loadout.get_trait_description(trait_id)
	if body == "":
		_set_description(title)
	else:
		_set_description("%s\n%s" % [title, body])


func _set_description(text: String) -> void:
	if detail_rule != null:
		detail_rule.visible = true
	if detail_footer != null:
		detail_footer.visible = true
		detail_footer.text = text
	if trait_detail != null:
		trait_detail.visible = false
		trait_detail.text = ""


func _rebuild_module_cards(loadout: PlayerWeaponLoadout) -> void:
	_clear_runtime_children(modules_grid)
	var traits := loadout.get_weapon_traits(_focused_weapon_id)
	var ids: Array[StringName] = []
	for key in traits.keys():
		if int(traits[key]) > 0:
			ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for trait_id in ids:
		modules_grid.add_child(_make_module_hex(
			loadout.get_trait_display_name(trait_id),
			int(traits[trait_id]),
			loadout.get_trait_icon(trait_id),
			trait_id,
			false,
		))
	_add_empty_module_placeholders()


func _add_empty_module_placeholders() -> void:
	while modules_grid != null and modules_grid.get_child_count() < MODULE_SLOT_COUNT:
		modules_grid.add_child(_make_module_hex("", 0, null, &"", true))


func _make_module_hex(
	_label_text: String,
	_rank: int,
	icon: Texture2D,
	trait_id: StringName,
	empty: bool,
) -> Control:
	assert(module_hex_template != null, "WeaponLoadoutHud requires %ModuleHexTemplate placeholder.")
	var hex := module_hex_template.duplicate() as HexModuleFrame
	hex.visible = true
	hex.apply_fixed_size(_module_hex_side())
	hex.border_width = 1.0
	hex.interactive = not empty
	hex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if empty:
		hex.set_module_text("", "")
		hex.set_module_icon(null)
		hex.border_color = Color(0.3, 0.55, 0.75, 0.5)
		hex.fill_color = Color(0.02, 0.06, 0.12, 0.2)
		hex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return hex

	hex.set_module_text("", "")
	hex.set_module_icon(icon)
	hex.border_color = Color(0.5, 0.92, 1.0, 0.95)
	hex.fill_color = Color(0.06, 0.18, 0.3, 0.95)
	if _rank > 0:
		hex.set_module_text("", _rank_roman(_rank))
	var captured := trait_id
	var on_hover := func() -> void:
		_focused_trait_id = captured
		_hover_trait_id = captured
		var loadout := _get_loadout()
		if loadout != null:
			_show_trait_description(loadout, captured)
	var on_exit := func() -> void:
		if _hover_trait_id != captured:
			return
		_hover_trait_id = &""
		var loadout := _get_loadout()
		if loadout != null and _focused_weapon_id != &"":
			_show_weapon_description(loadout)
	hex.module_hovered.connect(on_hover)
	hex.module_clicked.connect(on_hover)
	hex.mouse_exited.connect(on_exit)
	return hex


func _rank_roman(rank: int) -> String:
	return ROMAN[clampi(rank, 0, ROMAN.size() - 1)]


func _clear_runtime_children(container: Node) -> void:
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
