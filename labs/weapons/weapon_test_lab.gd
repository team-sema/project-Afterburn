class_name WeaponTestLab
extends Control

signal player_level_up_simulated(level: int)
signal enemy_augment_event_simulated(tier: int)

const ENCOUNTER_PRESET_DIRECTORY := "res://resources/encounters/presets"
const MAIN_ENCOUNTER_POOL := preload("res://resources/encounters/pools/main_encounter_pool.tres")
const SPECIAL_ENCOUNTER_IDS: Array[StringName] = [&"sniper_reinforcement", &"elite_escort_drone_pair"]
const ENEMY_ACCENT := Color(1.0, 0.22, 0.48, 1.0)
const PLAYER_ACCENT := Color(0.2, 0.82, 1.0, 1.0)
const ACTIVE_ACCENT := Color(0.35, 1.0, 0.55, 1.0)
const TRAIT_ACCENT := Color(0.72, 0.35, 1.0, 1.0)
const TEXT_COLOR := Color(0.82, 0.93, 1.0)
const DIM_TEXT_COLOR := Color(0.55, 0.66, 0.78)
const BUTTON_HEIGHT := 16
const COMPACT_BUTTON_HEIGHT := 14
const PICKER_CARD_HEIGHT := 44
const PLAYER_AUGMENT_KINDS: Array[PlayerAugmentKind.Kind] = [
	PlayerAugmentKind.Kind.FACILITY_EFFECT,
	PlayerAugmentKind.Kind.STAT_MULTIPLIER,
]

enum AugmentTestMode {
	PLAYER,
	ENEMY,
}

enum EnemyAugmentCategory {
	STAT,
	BEHAVIOR,
	SPAWN_RULE,
	EVOLUTION,
}

enum EncounterGroup {
	MAIN_POOL,
	ELITE_BOSS,
	SPECIAL,
	OTHER,
}

@export var weapon_definitions: Array[WeaponDefinition] = []

@onready var gameplay: Node2D = $Layout/Playfield/ViewportContainer/PlayfieldViewport/WeaponTestGameplay
@onready var ship: Node2D = gameplay.get_node("Ship") as Node2D
@onready var enemy_registry: EnemyAugmentRegistry = gameplay.get_node("EnemyAugmentRegistry") as EnemyAugmentRegistry
@onready var player_registry: PlayerAugmentRegistry = gameplay.get_node("PlayerAugmentRegistry") as PlayerAugmentRegistry
@onready var enemy_spawner: EnemySpawner = gameplay.get_node("EnemySpawner") as EnemySpawner
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
var _continuous_encounters: Dictionary = {}
var _continuous_spawn_enabled := false
var _enemy_encounters: Array[EncounterPreset] = []
var _player_augment_pool: Array[PlayerAugment] = []
var _enemy_augment_pool: Array[EnemyAugment] = []
var _augment_overlay: ColorRect
var _augment_list: VBoxContainer
var _augment_tabs: HBoxContainer
var _augment_tab_buttons: Array[Button] = []
var _augment_pages: Array[GridContainer] = []
var _augment_tab_index := 0
var _augment_reset_button: Button
var _augment_title: Label
var _augment_prompt: Label
var _augment_result: Label
var _augment_mode := AugmentTestMode.PLAYER
var _simulated_player_level := 0
var _simulated_enemy_tier := 0


func _ready() -> void:
	randomize()
	enemy_spawner.augment_registry = enemy_registry
	enemy_spawner.spawn_parent = gameplay
	_loadout = ship.get_weapon_loadout() as PlayerWeaponLoadout
	assert(_loadout != null, "Weapon test lab requires the ship weapon loadout.")
	_make_ship_invincible()
	_load_trait_definitions()
	_enemy_encounters = _load_encounter_presets()
	_build_enemy_buttons()
	_build_slot_buttons()
	_build_weapon_buttons()
	_load_augment_resources()
	_build_augment_overlay()
	_style_button(continuous_spawn_button, ACTIVE_ACCENT)
	_style_button(%ClearTargetsButton, ENEMY_ACCENT)
	_style_button(clear_traits_button, TRAIT_ACCENT)
	_style_button(unequip_button, PLAYER_ACCENT)
	%ClearTargetsButton.size_flags_horizontal = Control.SIZE_SHRINK_END
	%ClearTargetsButton.custom_minimum_size.x = 64
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
		KEY_Q, KEY_E:
			if is_augment_picker_open() and not _augment_tab_buttons.is_empty():
				var step := -1 if key == KEY_Q else 1
				_select_augment_tab(posmod(_augment_tab_index + step, _augment_tab_buttons.size()))
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
	_player_augment_pool = AugmentPoolLoader.load_player_augments(
		AugmentPoolLoader.DEFAULT_PLAYER_DIR,
		PLAYER_AUGMENT_KINDS,
		false,
	)
	_enemy_augment_pool = AugmentPoolLoader.load_enemy_augments(
		AugmentPoolLoader.DEFAULT_ENEMY_DIR,
		false,
	)


func _build_augment_overlay() -> void:
	_augment_overlay = ColorRect.new()
	_augment_overlay.name = "AugmentTestOverlay"
	_augment_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_augment_overlay.color = Color(0.0, 0.01, 0.035, 0.86)
	_augment_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_augment_overlay.z_index = 100
	_augment_overlay.hide()
	add_child(_augment_overlay)

	var panel := PanelContainer.new()
	panel.name = "PickerPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 18
	panel.offset_right = -24
	panel.offset_bottom = -18
	panel.add_theme_stylebox_override(
		"panel",
		_button_style(Color(0.2, 0.9, 1.0, 1.0), 0.98, 0.9),
	)
	_augment_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	_augment_title = Label.new()
	_augment_title.label_settings = preload("res://fonts/title_label_settings.tres").duplicate()
	header.add_child(_augment_title)
	_augment_prompt = Label.new()
	_augment_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_augment_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_augment_prompt.clip_text = true
	_augment_prompt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_augment_prompt.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	header.add_child(_augment_prompt)
	_augment_reset_button = Button.new()
	_augment_reset_button.name = "ResetAugmentsButton"
	_augment_reset_button.tooltip_text = "이 모드에서 적용한 증강을 모두 뗍니다."
	_augment_reset_button.pressed.connect(_reset_current_augments)
	_style_button(_augment_reset_button, ENEMY_ACCENT)
	_augment_reset_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_augment_reset_button.custom_minimum_size.x = 84
	header.add_child(_augment_reset_button)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "닫기 [Esc]"
	close_button.pressed.connect(close_augment_picker)
	_style_button(close_button, PLAYER_ACCENT)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.custom_minimum_size.x = 64
	header.add_child(close_button)

	_augment_tabs = HBoxContainer.new()
	_augment_tabs.name = "AugmentTabs"
	_augment_tabs.add_theme_constant_override("separation", 3)
	content.add_child(_augment_tabs)

	var scroll := ScrollContainer.new()
	scroll.name = "AugmentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_augment_list = VBoxContainer.new()
	_augment_list.name = "AugmentList"
	_augment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_augment_list)

	_augment_result = Label.new()
	_augment_result.name = "Result"
	_augment_result.add_theme_color_override("font_color", Color(1.0, 0.65, 0.8))
	content.add_child(_augment_result)


func _open_augment_picker(mode: AugmentTestMode) -> void:
	if mode != _augment_mode:
		_augment_tab_index = 0
	_augment_mode = mode
	_augment_result.text = ""
	var accent := PLAYER_ACCENT if mode == AugmentTestMode.PLAYER else ENEMY_ACCENT
	if mode == AugmentTestMode.PLAYER:
		_augment_title.text = "PLAYER Lv.%02d" % _simulated_player_level
		_augment_prompt.text = "시설 증강을 골라 즉시 설치  ·  떼기/우클릭으로 제거  ·  Q/E 탭"
	else:
		_augment_title.text = "THREAT %02d" % _simulated_enemy_tier
		_augment_prompt.text = "적 증강을 골라 이후 스폰에 적용  ·  떼기/우클릭으로 제거  ·  Q/E 탭"
	_augment_title.label_settings.font_color = accent
	_rebuild_augment_list()
	_augment_overlay.show()


func _rebuild_augment_list() -> void:
	for child in _augment_list.get_children() + _augment_tabs.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	_augment_tab_buttons.clear()
	_augment_pages.clear()
	if _augment_mode == AugmentTestMode.PLAYER:
		for kind in PLAYER_AUGMENT_KINDS:
			var page: GridContainer = null
			for augment in _player_augment_pool:
				if augment.augment_type != kind:
					continue
				if page == null:
					page = _add_augment_page(_player_augment_kind_label(kind), PLAYER_ACCENT)
				page.add_child(_create_player_augment_card(augment))
	else:
		var titles := ["스탯", "행동", "편성 · 규칙", "진화"]
		for category in EnemyAugmentCategory.values():
			var page: GridContainer = null
			for augment in _enemy_augment_pool:
				if _enemy_augment_category(augment) != category:
					continue
				if page == null:
					page = _add_augment_page(titles[category], ENEMY_ACCENT)
				page.add_child(_create_enemy_augment_card(augment))
	for index in _augment_pages.size():
		var tab := _augment_tab_buttons[index]
		var applied := 0
		for card in _augment_pages[index].get_children():
			applied += int(card.get_meta("applied_count", 0))
		tab.text = "%s  %d" % [tab.text, _augment_pages[index].get_child_count()]
		if applied > 0:
			tab.text += "  · %d" % applied
	var total_applied := _current_applied_count()
	_augment_reset_button.text = "전부 떼기 (%d)" % total_applied
	_augment_reset_button.disabled = total_applied <= 0
	_select_augment_tab(clampi(_augment_tab_index, 0, maxi(0, _augment_pages.size() - 1)))


func _add_augment_page(title: String, accent: Color) -> GridContainer:
	var index := _augment_pages.size()
	var tab := Button.new()
	tab.name = "Tab%d" % index
	tab.text = title
	tab.toggle_mode = true
	tab.pressed.connect(func() -> void: _select_augment_tab(index))
	_style_button(tab, accent)
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.custom_minimum_size.x = 72
	_augment_tabs.add_child(tab)
	var page := GridContainer.new()
	page.name = "Page%d" % index
	page.columns = 2
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("h_separation", 4)
	page.add_theme_constant_override("v_separation", 4)
	_augment_list.add_child(page)
	_augment_tab_buttons.append(tab)
	_augment_pages.append(page)
	return page


func _select_augment_tab(index: int) -> void:
	_augment_tab_index = index
	for page_index in _augment_pages.size():
		var selected := page_index == index
		_augment_pages[page_index].visible = selected
		_augment_tab_buttons[page_index].set_pressed_no_signal(selected)


func _enemy_augment_category(augment: EnemyAugment) -> EnemyAugmentCategory:
	if augment.is_evolution():
		return EnemyAugmentCategory.EVOLUTION
	if (
		augment.target_spawn_id != &""
		or augment.additional_spawn_count > 0
		or augment.elite_escort_preset != null
		or augment.player_reroll_penalty > 0
	):
		return EnemyAugmentCategory.SPAWN_RULE
	if not augment.stat_modifiers.is_empty():
		return EnemyAugmentCategory.STAT
	return EnemyAugmentCategory.BEHAVIOR


func _create_player_augment_card(augment: PlayerAugment) -> Button:
	var installed := player_registry.get_stack_count(augment.augment_id)
	var card := _create_augment_card(
		augment.get_offer_title(_loadout).replace("\n", " · "),
		"설치 ×%d" % installed if installed > 0 else "",
		augment.get_offer_description(_loadout),
		augment.icon,
		PLAYER_ACCENT,
		installed,
		_remove_player_augment.bind(augment),
	)
	card.name = "Player_%s" % String(augment.augment_id)
	card.pressed.connect(_on_player_augment_selected.bind(augment))
	return card


func _create_enemy_augment_card(augment: EnemyAugment) -> Button:
	var stack_count := enemy_registry.get_stack_count(augment.augment_id)
	var badges: PackedStringArray = []
	if not augment.include_in_offer_pool:
		badges.append("랩 전용")
	if stack_count > 0:
		if augment.max_stacks == 1:
			badges.append("적용됨")
		elif augment.max_stacks > 1:
			badges.append("×%d/%d" % [stack_count, augment.max_stacks])
		else:
			badges.append("×%d" % stack_count)
	var card := _create_augment_card(
		augment.display_name,
		" · ".join(badges),
		augment.description,
		augment.icon,
		ENEMY_ACCENT,
		stack_count,
		_remove_enemy_augment.bind(augment),
	)
	card.name = "Enemy_%s" % String(augment.augment_id)
	card.disabled = not enemy_registry.can_add_augment(augment)
	if card.disabled:
		card.tooltip_text = "%s\n\n최대 스택에 도달했습니다." % augment.description
	card.pressed.connect(_on_enemy_augment_selected.bind(augment))
	return card


func _create_augment_card(
	title: String,
	badge: String,
	description: String,
	icon: Texture2D,
	accent: Color,
	applied_count := 0,
	on_remove := Callable(),
) -> Button:
	var card := Button.new()
	card.tooltip_text = description
	card.set_meta("applied_count", applied_count)
	_style_button(card, accent)
	card.custom_minimum_size = Vector2(0, PICKER_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_top = 2
	row.offset_right = -5
	row.offset_bottom = -2
	row.add_theme_constant_override("separation", 5)
	card.add_child(row)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(18, 18)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)
	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_row)
	var title_label := _card_label(title, Color.WHITE)
	title_label.name = "Title"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title_label)
	if not badge.is_empty():
		var badge_label := _card_label(badge, accent.lightened(0.35))
		badge_label.name = "Badge"
		title_row.add_child(badge_label)
	var description_label := _card_label(description.replace("\n", " "), DIM_TEXT_COLOR)
	description_label.name = "Description"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.custom_minimum_size.x = 1
	text_box.add_child(description_label)
	if applied_count > 0 and on_remove.is_valid():
		var remove_button := Button.new()
		remove_button.name = "Remove"
		remove_button.text = "떼기"
		remove_button.tooltip_text = "한 스택을 뗍니다."
		_style_button(remove_button, ACTIVE_ACCENT, true)
		remove_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		remove_button.custom_minimum_size = Vector2(30, COMPACT_BUTTON_HEIGHT)
		remove_button.pressed.connect(on_remove)
		row.add_child(remove_button)
		# Right-click also removes; disabled (maxed) cards still receive it.
		card.gui_input.connect(func(event: InputEvent) -> void:
			var mouse := event as InputEventMouseButton
			if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
				on_remove.call()
				card.accept_event()
		)
	return card


func _card_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	return label


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


func _remove_enemy_augment(augment: EnemyAugment) -> void:
	if not enemy_registry.remove_augment(augment.augment_id):
		return
	_augment_result.text = "뗌 · %s (이후 스폰부터)" % augment.display_name
	_update_mode_badge("THREAT %d · 뗌 %s" % [_simulated_enemy_tier, augment.display_name])
	_rebuild_augment_list.call_deferred()


func _remove_player_augment(augment: PlayerAugment) -> void:
	if not player_registry.uninstall_augment(augment.augment_id):
		return
	_augment_result.text = "뗌 · %s" % augment.display_name
	_update_mode_badge("PLAYER · 뗌 %s" % augment.display_name)
	_refresh_loadout_ui()
	_rebuild_augment_list.call_deferred()


func _reset_current_augments() -> void:
	var count := _current_applied_count()
	if count <= 0:
		return
	if _augment_mode == AugmentTestMode.PLAYER:
		for augment in _player_augment_pool:
			while player_registry.uninstall_augment(augment.augment_id):
				pass
		_refresh_loadout_ui()
		_update_mode_badge("PLAYER · 시설 증강 %d개 모두 뗌" % count)
	else:
		while not enemy_registry.get_active_augments().is_empty():
			enemy_registry.remove_augment(enemy_registry.get_active_augments().back().augment_id)
		_update_mode_badge("THREAT · 적 증강 %d개 모두 뗌" % count)
	_augment_result.text = "모두 뗌 · %d개" % count
	_rebuild_augment_list.call_deferred()


func _current_applied_count() -> int:
	if _augment_mode == AugmentTestMode.PLAYER:
		var count := 0
		for augment in _player_augment_pool:
			count += player_registry.get_stack_count(augment.augment_id)
		return count
	return enemy_registry.get_active_augments().size()


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
			return "시설 모듈"
		PlayerAugmentKind.Kind.STAT_MULTIPLIER:
			return "레거시 스탯"
		_:
			return "기타"


func _update_mode_badge(status: String) -> void:
	var badge := $Layout/Playfield/ModeBadge/Label as Label
	badge.text = status


func _load_encounter_presets() -> Array[EncounterPreset]:
	var presets: Array[EncounterPreset] = []
	var files := DirAccess.get_files_at(ENCOUNTER_PRESET_DIRECTORY)
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var preset := load("%s/%s" % [ENCOUNTER_PRESET_DIRECTORY, file_name]) as EncounterPreset
		if preset != null:
			presets.append(preset)
	return presets


func _build_enemy_buttons() -> void:
	var titles := ["본 게임 풀", "엘리트 · 보스", "특수 스폰", "기타 · 레거시"]
	var grouped := {}
	for preset in _enemy_encounters:
		if preset == null:
			continue
		var group := _encounter_group(preset)
		if not grouped.has(group):
			grouped[group] = []
		(grouped[group] as Array).append(preset)
	for group in EncounterGroup.values():
		if not grouped.has(group):
			continue
		var presets := grouped[group] as Array
		var section := Label.new()
		section.name = "Section_%d" % group
		section.text = "%s  ·  %d" % [titles[group], presets.size()]
		section.add_theme_color_override("font_color", ENEMY_ACCENT.lightened(0.3))
		enemy_buttons.add_child(section)
		for preset in presets:
			enemy_buttons.add_child(_create_encounter_row(preset as EncounterPreset))


func _create_encounter_row(preset: EncounterPreset) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Enemy_%s" % String(preset.encounter_id)
	row.add_theme_constant_override("separation", 2)
	var button := Button.new()
	button.name = "Spawn_%s" % String(preset.encounter_id)
	button.text = String(preset.encounter_id)
	button.tooltip_text = "%s\n선택한 수만큼 이 스폰 패턴을 실행합니다." % String(preset.encounter_id)
	_style_button(button, ENEMY_ACCENT, true)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: _spawn_batches(preset))
	row.add_child(button)
	var repeat_toggle := Button.new()
	repeat_toggle.name = "Repeat_%s" % String(preset.encounter_id)
	repeat_toggle.toggle_mode = true
	repeat_toggle.text = "반복"
	repeat_toggle.tooltip_text = "지속 스폰에 이 프리셋을 포함합니다."
	_style_button(repeat_toggle, ACTIVE_ACCENT, true)
	repeat_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	repeat_toggle.custom_minimum_size.x = 28
	repeat_toggle.toggled.connect(
		func(enabled: bool) -> void: _set_encounter_repeating(preset, enabled)
	)
	row.add_child(repeat_toggle)
	return row


func _encounter_group(preset: EncounterPreset) -> EncounterGroup:
	for entry in MAIN_ENCOUNTER_POOL.entries:
		if entry != null and entry.preset != null and entry.preset.encounter_id == preset.encounter_id:
			return EncounterGroup.MAIN_POOL
	var encounter_id := String(preset.encounter_id)
	if encounter_id.begins_with("threat_elite") or encounter_id.begins_with("boss_"):
		return EncounterGroup.ELITE_BOSS
	if SPECIAL_ENCOUNTER_IDS.has(preset.encounter_id):
		return EncounterGroup.SPECIAL
	return EncounterGroup.OTHER


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
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 12)
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
		button.add_theme_constant_override("icon_max_width", 12)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = definition.description
		_style_button(button, PLAYER_ACCENT)
		button.pressed.connect(func() -> void: _equip_selected_slot(definition))
		weapon_buttons.add_child(button)
		_weapon_button_by_id[definition.id] = button


func _style_button(button: Button, accent: Color, compact := false) -> void:
	button.custom_minimum_size = Vector2(0, COMPACT_BUTTON_HEIGHT if compact else BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Side panels are 170px; long names trim instead of widening the panel.
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_COLOR, 0.35))
	button.add_theme_stylebox_override("normal", _button_style(accent, 0.12, 0.45, compact))
	button.add_theme_stylebox_override("hover", _button_style(accent, 0.22, 0.85, compact))
	button.add_theme_stylebox_override("pressed", _button_style(accent, 0.34, 1.0, compact))
	button.add_theme_stylebox_override("hover_pressed", _button_style(accent, 0.4, 1.0, compact))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", _button_style(accent, 0.05, 0.15, compact))


func _button_style(
	accent: Color,
	background_alpha: float,
	border_alpha: float,
	compact := false,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, background_alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2 if compact else 3)
	var margin := 3 if compact else 5
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _spawn_batches(preset: EncounterPreset) -> void:
	var batch_count := maxi(1, roundi(spawn_count.value))
	for batch_index in batch_count:
		enemy_spawner.spawn_encounter(
			preset,
			enemy_registry.get_additional_spawn_count(preset.encounter_id),
			Callable(self, "_configure_enemy_before_add"),
		)
	_refresh_target_count()


func _set_encounter_repeating(preset: EncounterPreset, enabled: bool) -> void:
	if enabled:
		_continuous_encounters[preset.encounter_id] = preset
	else:
		_continuous_encounters.erase(preset.encounter_id)
	continuous_spawn_button.disabled = _continuous_encounters.is_empty()
	if _continuous_encounters.is_empty() and _continuous_spawn_enabled:
		continuous_spawn_button.button_pressed = false
		_set_continuous_spawn(false)


func _set_continuous_spawn(enabled: bool) -> void:
	if enabled and _continuous_encounters.is_empty():
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
	for preset in _continuous_encounters.values():
		_spawn_batches(preset as EncounterPreset)


func _configure_enemy_before_add(enemy: Enemy) -> void:
	var experience_drop := enemy.get_node_or_null("ExperienceDropComponent") as ExperienceDropComponent
	if experience_drop != null:
		experience_drop.drop_chance = 0.0
	enemy.tree_exited.connect(func() -> void: call_deferred("_refresh_target_count"))


func _clear_targets() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if gameplay.is_ancestor_of(enemy):
			enemy.queue_free()
	EnemyBullets.cancel_all(gameplay, EnemyBullets.get_all(gameplay), EnemyBullets.REASON_LAB)
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
		button.icon = null
		if bay != null and not bay.is_empty():
			weapon_name = bay.equipped_weapon_display_name
			button.icon = _definition_icon(bay.equipped_weapon_id)
		button.text = str(index + 1)
		button.tooltip_text = "슬롯 %d · %s" % [index + 1, weapon_name]
		button.button_pressed = index == _selected_slot
		_style_button(
			button,
			Color(0.2, 0.9, 1.0, 1.0) if index == _selected_slot else Color(0.2, 0.5, 0.72, 1.0),
		)
		button.custom_minimum_size.y = 18

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
			"  · 장착" if equipped else "",
		]
		_style_button(weapon_button, ACTIVE_ACCENT if equipped else PLAYER_ACCENT)
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
		button.text = "%s  · Lv.%d" % [definition.display_name, rank] if active else definition.display_name
		_style_button(button, ACTIVE_ACCENT if active else TRAIT_ACCENT)
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
	trait_weapon_label.text = "%s 전용" % _loadout.get_weapon_display_name(weapon_id)
	trait_weapon_label.tooltip_text = "모듈을 누를 때마다 Lv이 오르고, 최대 Lv에서 누르면 해제됩니다."
	for definition in _trait_definitions:
		if definition.target_weapon_id != weapon_id:
			continue
		var button := Button.new()
		button.name = "Trait_%s" % String(definition.trait_id)
		button.toggle_mode = true
		button.icon = definition.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 12)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = definition.format_description(1)
		button.set_meta("definition", definition)
		button.pressed.connect(func() -> void: _toggle_selected_weapon_trait(definition))
		trait_buttons.add_child(button)
		_trait_button_by_id[definition.trait_id] = button


func _definition_icon(weapon_id: StringName) -> Texture2D:
	for definition in weapon_definitions:
		if definition != null and definition.id == weapon_id:
			return definition.icon
	return null


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
	target_count_label.text = "표적 %02d" % active_count


func _make_ship_invincible() -> void:
	var hurtbox := ship.get_node("PlayerHitPoint/HurtboxComponent") as HurtboxComponent
	assert(hurtbox != null, "Weapon test ship requires a HurtboxComponent.")
	hurtbox.is_invincible = true
