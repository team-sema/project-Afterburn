class_name WeaponCoreCluster
extends Control

## Central weapon hex with satellite trait hexes around it.

const HEX_MODULE_SCENE := preload("res://menus/hex_module_frame.tscn")

signal core_selected(weapon_id: StringName, is_record: bool)
signal trait_selected(weapon_id: StringName, trait_id: StringName, is_record: bool)

## Sized for the 200px STATUS rail (3 bays across ~160px usable width).
@export var core_size := Vector2(34, 34)
@export var trait_size := Vector2(14, 14)
@export var orbit_radius := 18.0

var weapon_id: StringName = &""
var is_record := false
var _core: HexModuleFrame
var _traits: Array[HexModuleFrame] = []
var _trait_ids: Array[StringName] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_minimum_size()
	_ensure_core()


func _refresh_minimum_size() -> void:
	var pad := orbit_radius * 1.2
	custom_minimum_size = Vector2(core_size.x + pad, core_size.y + pad)


func bind_weapon(
	p_weapon_id: StringName,
	icon: Texture2D,
	level: int,
	trait_ranks: Dictionary,
	p_is_record: bool,
	active: bool,
) -> void:
	weapon_id = p_weapon_id
	is_record = p_is_record
	_ensure_core()
	_core.interactive = true
	if p_weapon_id == &"":
		_core.set_module_text("", "")
		_core.set_module_icon(null)
		_core.dimmed = true
		_clear_traits()
		_style_core(false)
		return

	_core.set_module_text("", "Lv.%d" % level)
	_core.set_module_icon(icon)
	_core.dimmed = p_is_record or not active
	_style_core(active and not p_is_record)
	_rebuild_traits(trait_ranks)


func _ensure_core() -> void:
	if _core != null:
		return
	_core = HEX_MODULE_SCENE.instantiate() as HexModuleFrame
	_core.name = "Core"
	_core.custom_minimum_size = core_size
	_core.size = core_size
	_core.interactive = true
	add_child(_core)
	_core.module_hovered.connect(_on_core_hover)
	_core.module_clicked.connect(_on_core_click)
	_position_core()


func _position_core() -> void:
	if _core == null:
		return
	var center := size * 0.5 if size.x > 1.0 else custom_minimum_size * 0.5
	_core.position = center - core_size * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_core()
		_layout_traits()


func _rebuild_traits(trait_ranks: Dictionary) -> void:
	_clear_traits()
	var ids: Array[StringName] = []
	for key in trait_ranks.keys():
		if int(trait_ranks[key]) > 0:
			ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for index in ids.size():
		var trait_id := ids[index]
		var rank := int(trait_ranks[trait_id])
		var satellite := HEX_MODULE_SCENE.instantiate() as HexModuleFrame
		satellite.custom_minimum_size = trait_size
		satellite.size = trait_size
		satellite.interactive = true
		satellite.set_module_text("", str(rank) if rank > 1 else "")
		satellite.set_module_icon(null)
		satellite.dimmed = is_record
		satellite.border_color = Color(0.7, 0.85, 1.0, 0.9) if not is_record else Color(0.25, 0.4, 0.55, 0.7)
		satellite.fill_color = Color(0.08, 0.16, 0.28, 0.92) if not is_record else Color(0.04, 0.08, 0.12, 0.75)
		add_child(satellite)
		var captured := trait_id
		satellite.module_hovered.connect(func() -> void: trait_selected.emit(weapon_id, captured, is_record))
		satellite.module_clicked.connect(func() -> void: trait_selected.emit(weapon_id, captured, is_record))
		_traits.append(satellite)
		_trait_ids.append(trait_id)
	_layout_traits()


func _layout_traits() -> void:
	var center := size * 0.5 if size.x > 1.0 else custom_minimum_size * 0.5
	var count := _traits.size()
	for index in count:
		# Flat-top hex faces: start at 0° and step evenly.
		var angle := TAU * float(index) / float(maxi(1, count))
		var offset := Vector2(cos(angle), sin(angle)) * orbit_radius
		_traits[index].position = center + offset - trait_size * 0.5


func _clear_traits() -> void:
	for satellite in _traits:
		if is_instance_valid(satellite):
			satellite.queue_free()
	_traits.clear()
	_trait_ids.clear()


func _style_core(active: bool) -> void:
	if _core == null:
		return
	if active:
		_core.border_color = Color(0.45, 0.95, 1.0, 1.0)
		_core.fill_color = Color(0.06, 0.2, 0.34, 0.96)
		_core.border_width = 2.5
	elif is_record:
		_core.border_color = Color(0.2, 0.4, 0.55, 0.65)
		_core.fill_color = Color(0.03, 0.08, 0.12, 0.7)
		_core.border_width = 1.5
	else:
		_core.border_color = Color(0.25, 0.55, 0.7, 0.75)
		_core.fill_color = Color(0.04, 0.1, 0.16, 0.8)
		_core.border_width = 2.0
	_core.queue_redraw()


func _on_core_hover() -> void:
	core_selected.emit(weapon_id, is_record)


func _on_core_click() -> void:
	core_selected.emit(weapon_id, is_record)
