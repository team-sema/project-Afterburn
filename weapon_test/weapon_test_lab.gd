class_name WeaponTestLab
extends Control

const ENEMY_LABELS := {
	&"drone_formation": "드론 편대",
	&"striker": "스트라이커",
	&"awl_formation": "송곳 편대",
	&"bomb": "폭탄",
	&"caster": "캐스터",
}

@export var enemy_spawn_sets: Array[EnemySpawnSet] = []
@export var weapon_definitions: Array[WeaponDefinition] = []

@onready var gameplay: Node2D = $Layout/Playfield/ViewportContainer/PlayfieldViewport/WeaponTestGameplay
@onready var ship: Node2D = gameplay.get_node("Ship") as Node2D
@onready var enemy_registry: EnemyAugmentRegistry = gameplay.get_node("EnemyAugmentRegistry") as EnemyAugmentRegistry
@onready var enemy_buttons: VBoxContainer = %EnemyButtons
@onready var weapon_buttons: VBoxContainer = %WeaponButtons
@onready var spawn_count: SpinBox = %SpawnCount
@onready var target_count_label: Label = %TargetCount
@onready var slot_buttons: HBoxContainer = %SlotButtons
@onready var selected_slot_label: Label = %SelectedSlotLabel
@onready var level_button: Button = %LevelButton
@onready var unequip_button: Button = %UnequipButton

var _loadout: PlayerWeaponLoadout
var _selected_slot := 0
var _slot_button_list: Array[Button] = []
var _weapon_button_by_id: Dictionary = {}


func _ready() -> void:
	randomize()
	_loadout = ship.get_weapon_loadout() as PlayerWeaponLoadout
	assert(_loadout != null, "Weapon test lab requires the ship weapon loadout.")
	_make_ship_invincible()
	_build_enemy_buttons()
	_build_slot_buttons()
	_build_weapon_buttons()
	%ClearTargetsButton.pressed.connect(_clear_targets)
	level_button.pressed.connect(_level_up_selected_weapon)
	unequip_button.pressed.connect(_unequip_selected_slot)
	_loadout.loadout_changed.connect(_refresh_loadout_ui)
	_refresh_loadout_ui()
	_refresh_target_count()


func _build_enemy_buttons() -> void:
	for spawn_set in enemy_spawn_sets:
		if spawn_set == null:
			continue
		var button := Button.new()
		button.name = "Spawn_%s" % String(spawn_set.spawn_id)
		button.text = ENEMY_LABELS.get(spawn_set.spawn_id, String(spawn_set.spawn_id))
		button.tooltip_text = "선택한 수만큼 이 스폰 패턴을 실행합니다."
		_style_button(button, Color(1.0, 0.22, 0.48, 1.0))
		button.pressed.connect(func() -> void: _spawn_batches(spawn_set))
		enemy_buttons.add_child(button)


func _build_slot_buttons() -> void:
	for slot_index in _loadout.get_max_equipped_weapon_count():
		var button := Button.new()
		button.name = "Slot%d" % (slot_index + 1)
		button.custom_minimum_size = Vector2(0, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _select_slot(slot_index))
		slot_buttons.add_child(button)
		_slot_button_list.append(button)


func _build_weapon_buttons() -> void:
	for definition in weapon_definitions:
		if definition == null:
			continue
		var button := Button.new()
		button.name = "Weapon_%s" % String(definition.id)
		button.text = definition.display_name
		button.icon = definition.icon
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = definition.description
		_style_button(button, Color(0.16, 0.72, 1.0, 1.0))
		button.pressed.connect(func() -> void: _equip_selected_slot(definition))
		weapon_buttons.add_child(button)
		_weapon_button_by_id[definition.id] = button


func _style_button(button: Button, accent: Color) -> void:
	button.custom_minimum_size = Vector2(0, 28)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", Color(0.82, 0.93, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(accent, 0.12, 0.45))
	button.add_theme_stylebox_override("hover", _button_style(accent, 0.22, 0.85))
	button.add_theme_stylebox_override("pressed", _button_style(accent, 0.34, 1.0))
	button.add_theme_stylebox_override("focus", _button_style(accent, 0.2, 0.9))


func _button_style(accent: Color, background_alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, background_alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _spawn_batches(spawn_set: EnemySpawnSet) -> void:
	var batch_count := maxi(1, roundi(spawn_count.value))
	for batch_index in batch_count:
		spawn_set.spawn(gameplay.get_viewport_rect(), Callable(self, "_spawn_enemy"))
	_refresh_target_count()


func _spawn_enemy(
	enemy_scene: PackedScene,
	spawn_position: Vector2,
	configure: Callable,
) -> Node:
	var enemy := enemy_scene.instantiate() as Enemy
	assert(enemy != null, "Weapon test lab can only spawn Enemy scenes.")
	enemy.augment_registry = enemy_registry
	var experience_drop := enemy.get_node_or_null("ExperienceDropComponent") as ExperienceDropComponent
	if experience_drop != null:
		experience_drop.drop_chance = 0.0
	if configure.is_valid():
		configure.call(enemy)
	gameplay.add_child(enemy)
	enemy.global_position = spawn_position
	enemy.tree_exited.connect(func() -> void: call_deferred("_refresh_target_count"))
	return enemy


func _clear_targets() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if gameplay.is_ancestor_of(enemy):
			enemy.queue_free()
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if gameplay.is_ancestor_of(projectile):
			projectile.queue_free()
	for child in gameplay.get_children():
		if child is ExperienceOrb:
			child.queue_free()
	call_deferred("_refresh_target_count")


func _select_slot(slot_index: int) -> void:
	_selected_slot = clampi(slot_index, 0, _loadout.get_max_equipped_weapon_count() - 1)
	_refresh_loadout_ui()


func _equip_selected_slot(definition: WeaponDefinition) -> void:
	var equipped_slot := _loadout.find_equipped_slot(definition.id)
	if equipped_slot >= 0:
		_selected_slot = equipped_slot
		_refresh_loadout_ui()
		return
	var bay := _loadout.get_bay(_selected_slot)
	if bay != null and bay.is_empty():
		_loadout.equip_weapon(definition, _selected_slot)
	else:
		_loadout.request_replace_equipped(_selected_slot, definition)


func _level_up_selected_weapon() -> void:
	var bay := _loadout.get_bay(_selected_slot)
	if bay == null or bay.is_empty():
		return
	_loadout.upgrade_weapon_level(bay.equipped_weapon_id)


func _unequip_selected_slot() -> void:
	_loadout.unequip_weapon_at(_selected_slot)


func _refresh_loadout_ui() -> void:
	for index in _slot_button_list.size():
		var button := _slot_button_list[index]
		var bay := _loadout.get_bay(index)
		var weapon_name := "비어 있음"
		if bay != null and not bay.is_empty():
			weapon_name = bay.equipped_weapon_display_name
		button.text = str(index + 1)
		button.tooltip_text = weapon_name
		button.button_pressed = index == _selected_slot
		_style_button(
			button,
			Color(0.2, 0.9, 1.0, 1.0) if index == _selected_slot else Color(0.2, 0.5, 0.72, 1.0),
		)

	var selected_bay := _loadout.get_bay(_selected_slot)
	var selected_weapon_id: StringName = &""
	if selected_bay == null or selected_bay.is_empty():
		selected_slot_label.text = "선택 슬롯 %d · 비어 있음" % (_selected_slot + 1)
		level_button.disabled = true
		unequip_button.disabled = true
	else:
		selected_weapon_id = selected_bay.equipped_weapon_id
		selected_slot_label.text = "선택 슬롯 %d · %s Lv.%d" % [
			_selected_slot + 1,
			selected_bay.equipped_weapon_display_name,
			_loadout.get_weapon_level(selected_weapon_id),
		]
		level_button.disabled = not _loadout.can_upgrade_weapon(selected_weapon_id)
		unequip_button.disabled = false

	for weapon_id in _weapon_button_by_id:
		var weapon_button := _weapon_button_by_id[weapon_id] as Button
		var equipped := _loadout.is_weapon_equipped(weapon_id)
		weapon_button.text = "%s%s" % [
			_loadout.get_weapon_display_name(weapon_id) if equipped else _definition_name(weapon_id),
			"  [장착]" if equipped else "",
		]


func _definition_name(weapon_id: StringName) -> String:
	for definition in weapon_definitions:
		if definition != null and definition.id == weapon_id:
			return definition.display_name
	return String(weapon_id)


func _refresh_target_count() -> void:
	var active_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if gameplay.is_ancestor_of(enemy):
			active_count += 1
	target_count_label.text = "활성 표적  %02d" % active_count


func _make_ship_invincible() -> void:
	var hurtbox := ship.get_node("PlayerHitPoint/HurtboxComponent") as HurtboxComponent
	assert(hurtbox != null, "Weapon test ship requires a HurtboxComponent.")
	hurtbox.is_invincible = true
