class_name WeaponTestLab
extends Control

signal player_level_up_simulated(level: int)
signal enemy_augment_event_simulated(tier: int)

const ENEMY_LABELS := {
	&"drone_formation": "드론 편대",
	&"striker": "스트라이커",
	&"awl_formation": "송곳 편대",
	&"bomb": "폭탄",
	&"caster": "캐스터",
}
const PLAYER_AUGMENT_DIRECTORY := "res://resources/player_augments"
const ENEMY_AUGMENT_DIRECTORY := "res://resources/enemy_augments"
const PLAYER_AUGMENT_KINDS: Array[PlayerAugmentKind.Kind] = [
	PlayerAugmentKind.Kind.FACILITY_EFFECT,
	PlayerAugmentKind.Kind.STAT_MULTIPLIER,
]

enum AugmentTestMode {
	PLAYER,
	ENEMY,
}

@export var enemy_spawn_sets: Array[EnemySpawnSet] = []
@export var weapon_definitions: Array[WeaponDefinition] = []

@onready var gameplay: Node2D = $Layout/Playfield/ViewportContainer/PlayfieldViewport/WeaponTestGameplay
@onready var ship: Node2D = gameplay.get_node("Ship") as Node2D
@onready var enemy_registry: EnemyAugmentRegistry = gameplay.get_node("EnemyAugmentRegistry") as EnemyAugmentRegistry
@onready var player_registry: PlayerAugmentRegistry = gameplay.get_node("PlayerAugmentRegistry") as PlayerAugmentRegistry
@onready var enemy_buttons: VBoxContainer = %EnemyButtons
@onready var weapon_buttons: VBoxContainer = %WeaponButtons
@onready var spawn_count: SpinBox = %SpawnCount
@onready var continuous_spawn_interval: SpinBox = %ContinuousSpawnInterval
@onready var continuous_spawn_button: Button = %ContinuousSpawnButton
@onready var continuous_spawn_timer: Timer = %ContinuousSpawnTimer
@onready var target_count_label: Label = %TargetCount
@onready var slot_buttons: HBoxContainer = %SlotButtons
@onready var selected_slot_label: Label = %SelectedSlotLabel
@onready var trait_weapon_label: Label = %TraitWeaponLabel
@onready var trait_buttons: VBoxContainer = %TraitButtons
@onready var clear_traits_button: Button = %ClearTraitsButton
@onready var unequip_button: Button = %UnequipButton

var _loadout: PlayerWeaponLoadout
var _selected_slot := 0
var _slot_button_list: Array[Button] = []
var _weapon_button_by_id: Dictionary = {}
var _trait_definitions: Array[WeaponTraitDefinition] = []
var _trait_button_by_id: Dictionary = {}
var _displayed_trait_weapon_id: StringName = &""
var _continuous_spawn_sets: Dictionary = {}
var _continuous_spawn_enabled := false
var _player_augment_pool: Array[PlayerAugment] = []
var _enemy_augment_pool: Array[EnemyAugment] = []
var _augment_overlay: ColorRect
var _augment_list: VBoxContainer
var _augment_title: Label
var _augment_prompt: Label
var _augment_result: Label
var _augment_mode := AugmentTestMode.PLAYER
var _simulated_player_level := 0
var _simulated_enemy_tier := 0


func _ready() -> void:
	randomize()
	_loadout = ship.get_weapon_loadout() as PlayerWeaponLoadout
	assert(_loadout != null, "Weapon test lab requires the ship weapon loadout.")
	_make_ship_invincible()
	_load_trait_definitions()
	_build_enemy_buttons()
	_build_slot_buttons()
	_build_weapon_buttons()
	_load_augment_resources()
	_build_augment_overlay()
	%ClearTargetsButton.pressed.connect(_clear_targets)
	continuous_spawn_button.toggled.connect(_set_continuous_spawn)
	continuous_spawn_interval.value_changed.connect(_on_continuous_spawn_interval_changed)
	continuous_spawn_timer.timeout.connect(_spawn_continuous_batches)
	clear_traits_button.pressed.connect(_clear_selected_weapon_traits)
	unequip_button.pressed.connect(_unequip_selected_slot)
	_loadout.loadout_changed.connect(_refresh_loadout_ui)
	_refresh_loadout_ui()
	_refresh_target_count()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	if key == KEY_NONE:
		key = key_event.keycode
	match key:
		KEY_C:
			open_player_augment_picker()
			get_viewport().set_input_as_handled()
		KEY_V:
			open_enemy_augment_picker()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if is_augment_picker_open():
				close_augment_picker()
				get_viewport().set_input_as_handled()


func open_player_augment_picker() -> void:
	_simulated_player_level += 1
	player_level_up_simulated.emit(_simulated_player_level)
	_open_augment_picker(AugmentTestMode.PLAYER)


func open_enemy_augment_picker() -> void:
	_simulated_enemy_tier += 1
	enemy_augment_event_simulated.emit(_simulated_enemy_tier)
	_open_augment_picker(AugmentTestMode.ENEMY)


func close_augment_picker() -> void:
	if _augment_overlay != null:
		_augment_overlay.hide()


func is_augment_picker_open() -> bool:
	return _augment_overlay != null and _augment_overlay.visible


func get_player_augment_count() -> int:
	return _player_augment_pool.size()


func get_enemy_augment_count() -> int:
	return _enemy_augment_pool.size()


func _load_augment_resources() -> void:
	_collect_augment_resources(PLAYER_AUGMENT_DIRECTORY)
	_collect_augment_resources(ENEMY_AUGMENT_DIRECTORY)
	_player_augment_pool.sort_custom(
		func(a: PlayerAugment, b: PlayerAugment) -> bool:
			if a.augment_type != b.augment_type:
				return a.augment_type < b.augment_type
			return String(a.augment_id) < String(b.augment_id)
	)
	_enemy_augment_pool.sort_custom(
		func(a: EnemyAugment, b: EnemyAugment) -> bool:
			return String(a.augment_id) < String(b.augment_id)
	)


func _collect_augment_resources(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("WeaponTestLab: cannot open augment directory '%s'." % directory_path)
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var resource_path := directory_path.path_join(file_name)
			if directory.current_is_dir():
				_collect_augment_resources(resource_path)
			elif file_name.ends_with(".tres"):
				var resource := load(resource_path)
				if resource is PlayerAugment:
					var player_augment := resource as PlayerAugment
					if player_augment.augment_type in PLAYER_AUGMENT_KINDS:
						_player_augment_pool.append(player_augment)
				elif resource is EnemyAugment:
					_enemy_augment_pool.append(resource as EnemyAugment)
		file_name = directory.get_next()
	directory.list_dir_end()


func _build_augment_overlay() -> void:
	_augment_overlay = ColorRect.new()
	_augment_overlay.name = "AugmentTestOverlay"
	_augment_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_augment_overlay.color = Color(0.0, 0.01, 0.035, 0.92)
	_augment_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_augment_overlay.z_index = 100
	_augment_overlay.hide()
	add_child(_augment_overlay)

	var panel := PanelContainer.new()
	panel.name = "PickerPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -166)
	panel.size = Vector2(500, 332)
	panel.add_theme_stylebox_override(
		"panel",
		_button_style(Color(0.2, 0.9, 1.0, 1.0), 0.98, 0.9),
	)
	_augment_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_augment_title = Label.new()
	_augment_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_augment_title.label_settings = preload("res://fonts/title_label_settings.tres")
	header.add_child(_augment_title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "닫기 [Esc]"
	close_button.pressed.connect(close_augment_picker)
	header.add_child(close_button)

	_augment_prompt = Label.new()
	_augment_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_augment_prompt)

	var scroll := ScrollContainer.new()
	scroll.name = "AugmentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_augment_list = VBoxContainer.new()
	_augment_list.name = "AugmentList"
	_augment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_augment_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_augment_list)

	_augment_result = Label.new()
	_augment_result.name = "Result"
	_augment_result.add_theme_color_override("font_color", Color(1.0, 0.65, 0.8))
	content.add_child(_augment_result)


func _open_augment_picker(mode: AugmentTestMode) -> void:
	_augment_mode = mode
	_augment_result.text = ""
	if mode == AugmentTestMode.PLAYER:
		_augment_title.text = "PLAYER LEVEL UP  ·  %02d" % _simulated_player_level
		_augment_prompt.text = "C · 시설 증강 중 하나를 선택해 즉시 적용"
	else:
		_augment_title.text = "ENEMY AUGMENT  ·  THREAT %02d" % _simulated_enemy_tier
		_augment_prompt.text = "V · 모든 적 증강 중 하나를 선택해 이후 스폰에 적용"
	_rebuild_augment_list()
	_augment_overlay.show()


func _rebuild_augment_list() -> void:
	for child in _augment_list.get_children():
		_augment_list.remove_child(child)
		child.queue_free()
	if _augment_mode == AugmentTestMode.PLAYER:
		for kind in PLAYER_AUGMENT_KINDS:
			var kind_augments: Array[PlayerAugment] = []
			for augment in _player_augment_pool:
				if augment.augment_type == kind:
					kind_augments.append(augment)
			if kind_augments.is_empty():
				continue
			_add_augment_section(_player_augment_kind_label(kind), Color(0.25, 0.85, 1.0))
			for augment in kind_augments:
				_add_player_augment_button(augment)
	else:
		_add_augment_section("ENEMY AUGMENTS", Color(1.0, 0.28, 0.55))
		for augment in _enemy_augment_pool:
			_add_enemy_augment_button(augment)


func _add_augment_section(title: String, accent: Color) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", accent)
	_augment_list.add_child(label)


func _add_player_augment_button(augment: PlayerAugment) -> void:
	var button := _create_augment_button(
		augment.get_offer_title(_loadout).replace("\n", " · "),
		String(augment.augment_id),
		augment.get_offer_description(_loadout),
		Color(0.2, 0.82, 1.0),
	)
	button.name = "Player_%s" % String(augment.augment_id)
	button.pressed.connect(_on_player_augment_selected.bind(augment))
	_augment_list.add_child(button)


func _add_enemy_augment_button(augment: EnemyAugment) -> void:
	var stack_count := enemy_registry.get_stack_count(augment.augment_id)
	var suffix := " · STACK %d" % stack_count if stack_count > 0 else ""
	var button := _create_augment_button(
		augment.display_name + suffix,
		String(augment.augment_id),
		augment.description,
		Color(1.0, 0.28, 0.55),
	)
	button.name = "Enemy_%s" % String(augment.augment_id)
	button.disabled = not enemy_registry.can_add_augment(augment)
	if button.disabled:
		button.tooltip_text = "%s\n\n최대 스택에 도달했습니다." % augment.description
	button.pressed.connect(_on_enemy_augment_selected.bind(augment))
	_augment_list.add_child(button)


func _create_augment_button(
	title: String,
	augment_id: String,
	description: String,
	accent: Color,
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 50)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "%s  [%s]\n%s" % [title, augment_id, description.replace("\n", " ")]
	button.tooltip_text = description
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_style_button(button, accent)
	return button


func _on_player_augment_selected(augment: PlayerAugment) -> void:
	if not _apply_player_augment(augment):
		_augment_result.text = "적용 실패 · 현재 상태를 확인하세요."
		return
	_refresh_loadout_ui()
	_update_mode_badge("PLAYER Lv.%d · %s" % [_simulated_player_level, augment.display_name])
	close_augment_picker()


func _on_enemy_augment_selected(augment: EnemyAugment) -> void:
	if not enemy_registry.can_add_augment(augment):
		_augment_result.text = "적용 실패 · 최대 스택입니다."
		_rebuild_augment_list()
		return
	enemy_registry.add_augment(augment)
	_update_mode_badge("THREAT %d · %s" % [_simulated_enemy_tier, augment.display_name])
	close_augment_picker()


func _apply_player_augment(augment: PlayerAugment) -> bool:
	match augment.augment_type:
		PlayerAugmentKind.Kind.FACILITY_EFFECT:
			if not player_registry.has_facility(augment.get_primary_module_tag()):
				return false
			var replace_index := -1
			if not player_registry.has_empty_slot():
				if player_registry.can_expand_slots():
					player_registry.expand_slots()
				else:
					replace_index = 0
			return player_registry.install_augment(augment, &"", replace_index) >= 0
		_:
			return false


func _player_augment_kind_label(kind: PlayerAugmentKind.Kind) -> String:
	match kind:
		PlayerAugmentKind.Kind.FACILITY_EFFECT:
			return "FACILITY MODULES"
		PlayerAugmentKind.Kind.STAT_MULTIPLIER:
			return "LEGACY STAT"
		_:
			return "OTHER"


func _update_mode_badge(status: String) -> void:
	var badge := $Layout/Playfield/ModeBadge/Label as Label
	badge.text = "AUGMENT TEST LAB  ·  %s" % status


func _build_enemy_buttons() -> void:
	for spawn_set in enemy_spawn_sets:
		if spawn_set == null:
			continue
		var row := HBoxContainer.new()
		row.name = "Enemy_%s" % String(spawn_set.spawn_id)
		row.add_theme_constant_override("separation", 4)
		var button := Button.new()
		button.name = "Spawn_%s" % String(spawn_set.spawn_id)
		button.text = ENEMY_LABELS.get(spawn_set.spawn_id, String(spawn_set.spawn_id))
		button.tooltip_text = "선택한 수만큼 이 스폰 패턴을 실행합니다."
		_style_button(button, Color(1.0, 0.22, 0.48, 1.0))
		button.pressed.connect(func() -> void: _spawn_batches(spawn_set))
		row.add_child(button)
		var repeat_toggle := CheckButton.new()
		repeat_toggle.name = "Repeat_%s" % String(spawn_set.spawn_id)
		repeat_toggle.custom_minimum_size = Vector2(54, 24)
		repeat_toggle.text = "반복"
		repeat_toggle.tooltip_text = "지속 스폰 모드에 이 적을 포함합니다."
		repeat_toggle.toggled.connect(
			func(enabled: bool) -> void: _set_spawn_set_repeating(spawn_set, enabled)
		)
		row.add_child(repeat_toggle)
		enemy_buttons.add_child(row)


func _load_trait_definitions() -> void:
	var directory := "res://resources/weapons/traits"
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var definition := load("%s/%s" % [directory, file_name]) as WeaponTraitDefinition
		if definition != null:
			_trait_definitions.append(definition)


func _build_slot_buttons() -> void:
	for slot_index in _loadout.get_max_equipped_weapon_count():
		var button := Button.new()
		button.name = "Slot%d" % (slot_index + 1)
		button.custom_minimum_size = Vector2(0, 24)
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
	button.custom_minimum_size = Vector2(0, 24)
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
		spawn_set.spawn(
			gameplay.get_viewport_rect(),
			Callable(self, "_spawn_enemy"),
			enemy_registry.get_additional_spawn_count(spawn_set.spawn_id),
		)
	_refresh_target_count()


func _set_spawn_set_repeating(spawn_set: EnemySpawnSet, enabled: bool) -> void:
	if enabled:
		_continuous_spawn_sets[spawn_set.spawn_id] = spawn_set
	else:
		_continuous_spawn_sets.erase(spawn_set.spawn_id)
	continuous_spawn_button.disabled = _continuous_spawn_sets.is_empty()
	if _continuous_spawn_sets.is_empty() and _continuous_spawn_enabled:
		continuous_spawn_button.button_pressed = false
		_set_continuous_spawn(false)


func _set_continuous_spawn(enabled: bool) -> void:
	if enabled and _continuous_spawn_sets.is_empty():
		continuous_spawn_button.button_pressed = false
		return
	_continuous_spawn_enabled = enabled
	continuous_spawn_button.text = "지속 스폰 중지" if enabled else "지속 스폰 시작"
	if enabled:
		continuous_spawn_timer.start(continuous_spawn_interval.value)
	else:
		continuous_spawn_timer.stop()


func _on_continuous_spawn_interval_changed(interval: float) -> void:
	if _continuous_spawn_enabled:
		continuous_spawn_timer.start(interval)


func _spawn_continuous_batches() -> void:
	if not _continuous_spawn_enabled:
		return
	for spawn_set in _continuous_spawn_sets.values():
		_spawn_batches(spawn_set as EnemySpawnSet)


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


func _unequip_selected_slot() -> void:
	_loadout.unequip_weapon_at(_selected_slot)


func _toggle_selected_weapon_trait(definition: WeaponTraitDefinition) -> void:
	var bay := _loadout.get_bay(_selected_slot)
	if bay == null or bay.is_empty() or definition.target_weapon_id != bay.equipped_weapon_id:
		return
	var current_rank := int(
		_loadout.get_weapon_traits(bay.equipped_weapon_id).get(definition.trait_id, 0)
	)
	var rank_change := 1
	if current_rank >= definition.max_rank:
		rank_change = -current_rank
	_loadout.add_or_upgrade_weapon_trait(
		bay.equipped_weapon_id,
		definition.trait_id,
		rank_change,
	)


func _clear_selected_weapon_traits() -> void:
	var bay := _loadout.get_bay(_selected_slot)
	if bay == null or bay.is_empty():
		return
	var active_traits := _loadout.get_weapon_traits(bay.equipped_weapon_id)
	for trait_id in active_traits:
		var rank := int(active_traits[trait_id])
		if rank > 0:
			_loadout.add_or_upgrade_weapon_trait(bay.equipped_weapon_id, trait_id, -rank)


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
		unequip_button.disabled = true
	else:
		selected_weapon_id = selected_bay.equipped_weapon_id
		selected_slot_label.text = "선택 슬롯 %d · %s" % [
			_selected_slot + 1,
			selected_bay.equipped_weapon_display_name,
		]
		unequip_button.disabled = false

	for weapon_id in _weapon_button_by_id:
		var weapon_button := _weapon_button_by_id[weapon_id] as Button
		var equipped := _loadout.is_weapon_equipped(weapon_id)
		weapon_button.text = "%s%s" % [
			_loadout.get_weapon_display_name(weapon_id) if equipped else _definition_name(weapon_id),
			"  [장착]" if equipped else "",
		]
	_refresh_trait_ui(selected_weapon_id)


func _refresh_trait_ui(weapon_id: StringName) -> void:
	if weapon_id != _displayed_trait_weapon_id:
		_rebuild_trait_buttons(weapon_id)
	var active_traits := _loadout.get_weapon_traits(weapon_id)
	var has_active_trait := false
	for trait_id in _trait_button_by_id:
		var button := _trait_button_by_id[trait_id] as Button
		var definition := button.get_meta("definition") as WeaponTraitDefinition
		var rank := int(active_traits.get(trait_id, 0))
		var active := rank > 0
		has_active_trait = has_active_trait or active
		button.button_pressed = active
		button.text = "%s  %s" % ["[Lv.%d]" % rank if active else "[  ]", definition.display_name]
		_style_button(
			button,
			Color(0.35, 1.0, 0.55, 1.0) if active else Color(0.72, 0.35, 1.0, 1.0),
		)
	clear_traits_button.disabled = weapon_id == &"" or not has_active_trait


func _rebuild_trait_buttons(weapon_id: StringName) -> void:
	_displayed_trait_weapon_id = weapon_id
	_trait_button_by_id.clear()
	for child in trait_buttons.get_children():
		trait_buttons.remove_child(child)
		child.queue_free()
	if weapon_id == &"":
		trait_weapon_label.text = "무기를 장착하면 모듈이 표시됩니다."
		return
	trait_weapon_label.text = "%s 전용 모듈 · 클릭 시 Lv.I→III→해제" % _loadout.get_weapon_display_name(weapon_id)
	for definition in _trait_definitions:
		if definition.target_weapon_id != weapon_id:
			continue
		var button := Button.new()
		button.name = "Trait_%s" % String(definition.trait_id)
		button.toggle_mode = true
		button.icon = definition.icon
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = definition.description
		button.set_meta("definition", definition)
		button.pressed.connect(func() -> void: _toggle_selected_weapon_trait(definition))
		trait_buttons.add_child(button)
		_trait_button_by_id[definition.trait_id] = button


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
