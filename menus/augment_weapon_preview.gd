class_name AugmentWeaponPreview
extends Control

const ROMAN := ["", "I", "II", "III", "IV", "V"]

@onready var slot_panels: Array[PanelContainer] = [
	%SlotPanel1,
	%SlotPanel2,
	%SlotPanel3,
]
@onready var slot_headers: Array[Label] = [
	%SlotHeader1,
	%SlotHeader2,
	%SlotHeader3,
]
@onready var slot_icons: Array[TextureRect] = [
	%SlotIcon1,
	%SlotIcon2,
	%SlotIcon3,
]
@onready var slot_names: Array[Label] = [
	%SlotName1,
	%SlotName2,
	%SlotName3,
]
@onready var slot_meta: Array[Label] = [
	%SlotMeta1,
	%SlotMeta2,
	%SlotMeta3,
]
@onready var context_label: Label = %ContextLabel
@onready var change_label: Label = %ChangeLabel
@onready var trait_label: Label = %TraitLabel
@onready var candidate_icon: TextureRect = %CandidateIcon

var _loadout: PlayerWeaponLoadout
var _augment: PlayerAugment
var _normal_panel_style: StyleBox
var _focused_panel_style: StyleBox


func _ready() -> void:
	_normal_panel_style = slot_panels[0].get_theme_stylebox("panel").duplicate()
	_focused_panel_style = slot_panels[0].get_theme_stylebox("focused_panel").duplicate()
	refresh()


func set_loadout(loadout: PlayerWeaponLoadout) -> void:
	if _loadout != null and _loadout.loadout_changed.is_connected(refresh):
		_loadout.loadout_changed.disconnect(refresh)
	_loadout = loadout
	if _loadout != null and not _loadout.loadout_changed.is_connected(refresh):
		_loadout.loadout_changed.connect(refresh)
	refresh()


func show_augment(augment: PlayerAugment) -> void:
	_augment = augment
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	_render_current_loadout()
	if _augment == null or not PlayerAugmentKind.is_weapon_offer(_augment.augment_type):
		_clear_detail()
		return
	match _augment.augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			_preview_acquire()
		PlayerAugmentKind.Kind.WEAPON_LEVEL:
			_preview_level()
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			_preview_trait()


func _render_current_loadout() -> void:
	for index in slot_panels.size():
		_set_slot_focused(index, false)
		slot_headers[index].text = "병기 %d" % (index + 1)
		if _loadout == null or index >= _loadout.get_max_equipped_weapon_count():
			_set_empty_slot(index)
			continue
		var bay := _loadout.get_bay(index)
		if bay == null or bay.is_empty():
			_set_empty_slot(index)
			continue
		var weapon_id := bay.equipped_weapon_id
		slot_icons[index].texture = _loadout.get_weapon_icon(weapon_id)
		slot_icons[index].visible = slot_icons[index].texture != null
		slot_names[index].text = bay.equipped_weapon_display_name
		var trait_count := _count_active_traits(_loadout.get_weapon_traits(weapon_id))
		slot_meta[index].text = "Lv.%d · 증강 %d" % [
			_loadout.get_weapon_level(weapon_id),
			trait_count,
		]


func _preview_acquire() -> void:
	var definition := _augment.weapon_definition
	var weapon_name := _weapon_name(_augment.get_weapon_id(), definition)
	var starting_level := _augment.starting_weapon_level
	context_label.text = "신규 병기 획득"
	change_label.text = "%s · Lv.%d" % [weapon_name, starting_level]
	trait_label.text = "새 병기가 병기 배치에 추가됩니다."
	candidate_icon.texture = definition.icon if definition != null else _augment.get_offer_icon()
	candidate_icon.visible = candidate_icon.texture != null
	if _loadout == null:
		return
	var empty_index := _loadout.get_first_empty_bay()
	if empty_index >= 0 and empty_index < slot_panels.size():
		slot_headers[empty_index].text = "신규 배치"
		slot_icons[empty_index].texture = candidate_icon.texture
		slot_icons[empty_index].visible = candidate_icon.visible
		slot_names[empty_index].text = weapon_name
		slot_meta[empty_index].text = "Lv.%d · 획득 예정" % starting_level
		_set_slot_focused(empty_index, true)
		return
	trait_label.text = "병기 배치가 가득 찼습니다. 선택 후 교체할 병기를 지정합니다."


func _preview_level() -> void:
	var weapon_id := _resolve_target_weapon_id()
	var current_level := _loadout.get_weapon_level(weapon_id) if _loadout != null else 1
	context_label.text = "병기 코어 강화"
	change_label.text = "%s · Lv.%d → Lv.%d" % [
		_weapon_name(weapon_id, _augment.weapon_definition),
		current_level,
		mini(current_level + 1, PlayerWeaponLoadout.MAX_WEAPON_LEVEL),
	]
	trait_label.text = _current_trait_summary(weapon_id)
	candidate_icon.texture = _weapon_icon(weapon_id)
	candidate_icon.visible = candidate_icon.texture != null
	_focus_weapon(weapon_id)


func _preview_trait() -> void:
	var weapon_id := _resolve_target_weapon_id()
	var trait_id := _augment.trait_id
	var trait_name := _trait_name(trait_id)
	var current_rank := 0
	if _loadout != null:
		current_rank = int(_loadout.get_weapon_traits(weapon_id).get(trait_id, 0))
	var next_rank := current_rank + _augment.trait_rank_increase
	context_label.text = "병기 증강 장착"
	change_label.text = "%s · %s" % [
		_weapon_name(weapon_id, _augment.weapon_definition),
		trait_name,
	]
	var rank_change := "신규 → %s" % _rank_roman(next_rank)
	if current_rank > 0:
		rank_change = "%s → %s" % [_rank_roman(current_rank), _rank_roman(next_rank)]
	trait_label.text = "%s\n추가: %s %s" % [
		_current_trait_summary(weapon_id),
		trait_name,
		rank_change,
	]
	candidate_icon.texture = _augment.get_offer_icon()
	if candidate_icon.texture == null:
		candidate_icon.texture = _weapon_icon(weapon_id)
	candidate_icon.visible = candidate_icon.texture != null
	_focus_weapon(weapon_id)


func _focus_weapon(weapon_id: StringName) -> void:
	if _loadout == null:
		return
	var index := _loadout.find_equipped_slot(weapon_id)
	if index >= 0 and index < slot_panels.size():
		_set_slot_focused(index, true)


func _resolve_target_weapon_id() -> StringName:
	var weapon_id := _augment.get_weapon_id()
	if weapon_id == &"" and _augment.trait_definition != null:
		weapon_id = _augment.trait_definition.target_weapon_id
	if weapon_id == &"" and _loadout != null:
		var equipped := _loadout.get_equipped_weapon_ids()
		if not equipped.is_empty():
			weapon_id = equipped[0]
	return weapon_id


func _current_trait_summary(weapon_id: StringName) -> String:
	if _loadout == null:
		return "현재 증강: 없음"
	var traits := _loadout.get_weapon_traits(weapon_id)
	var names: PackedStringArray = []
	var ids: Array[StringName] = []
	for key in traits.keys():
		if int(traits[key]) > 0:
			ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for trait_id in ids:
		names.append("%s %s" % [_trait_name(trait_id), _rank_roman(int(traits[trait_id]))])
	return "현재 증강: %s" % ("없음" if names.is_empty() else ", ".join(names))


func _trait_name(trait_id: StringName) -> String:
	if _augment != null and _augment.trait_definition != null:
		if _augment.trait_definition.trait_id == trait_id:
			return _augment.trait_definition.display_name
	if _loadout != null:
		return _loadout.get_trait_display_name(trait_id)
	return String(trait_id)


func _weapon_name(weapon_id: StringName, definition: WeaponDefinition) -> String:
	if definition != null and definition.display_name != "":
		return definition.display_name
	if _loadout != null:
		return _loadout.get_weapon_display_name(weapon_id)
	return String(weapon_id)


func _weapon_icon(weapon_id: StringName) -> Texture2D:
	if _loadout != null:
		return _loadout.get_weapon_icon(weapon_id)
	if _augment != null:
		return _augment.get_offer_icon()
	return null


func _set_empty_slot(index: int) -> void:
	slot_icons[index].texture = null
	slot_icons[index].visible = false
	slot_names[index].text = "빈 슬롯"
	slot_meta[index].text = "배치 가능"


func _set_slot_focused(index: int, focused: bool) -> void:
	if _normal_panel_style == null or _focused_panel_style == null:
		return
	slot_panels[index].add_theme_stylebox_override(
		"panel",
		_focused_panel_style if focused else _normal_panel_style,
	)


func _clear_detail() -> void:
	context_label.text = "병기 적용 미리보기"
	change_label.text = "병기 증강 카드를 선택하세요."
	trait_label.text = ""
	candidate_icon.texture = null
	candidate_icon.visible = false


func _count_active_traits(traits: Dictionary) -> int:
	var count := 0
	for rank in traits.values():
		if int(rank) > 0:
			count += 1
	return count


func _rank_roman(rank: int) -> String:
	return ROMAN[clampi(rank, 0, ROMAN.size() - 1)]
