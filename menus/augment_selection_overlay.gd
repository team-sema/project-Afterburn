class_name AugmentSelectionOverlay
extends CanvasLayer

signal choice_selected(choice: Resource)
signal facility_expansion_selected(facility_id: StringName)
signal reroll_requested

const CHOICE_ICON_MAX_WIDTH := 28
const ENEMY_CHOICE_ICON_MAX_WIDTH := 48
const FACILITY_GRID := [
	[&"weapon_room", &"hangar"],
	[&"engine", &"hull"],
	[&"radar", &"shield"],
]

@export var player_accent_color: Color
@export var enemy_accent_color: Color
@export_range(0.01, 5.0, 0.01) var open_duration := 0.2
@export_range(0.01, 5.0, 0.01) var phase_transition_duration := 0.5
@export_range(0.0, 5.0, 0.01) var result_hold_duration := 0.45
@export_range(0.01, 5.0, 0.01) var close_duration := 0.22

@onready var backdrop: ColorRect = $Backdrop
@onready var breakpoint_intro: AugmentBreakpointIntro = $BreakpointIntro
@onready var choice_container: MarginContainer = $MarginContainer
@onready var panel_container: PanelContainer = $MarginContainer/PanelContainer
@onready var content_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer
@onready var accent_bar: ColorRect = $MarginContainer/PanelContainer/VBoxContainer/AccentBar
@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var ship_separator: HSeparator = %ShipSeparator
@onready var slot_action_label: Label = %SlotActionLabel
@onready var offer_ship_panel: ShipPanel = %OfferShipPanel
@onready var offer_weapon_preview: AugmentWeaponPreview = %OfferWeaponPreview
@onready var choice_buttons: Array[Button] = [
	%ChoiceButton1,
	%ChoiceButton2,
	%ChoiceButton3,
]
@onready var reroll_button: Button = get_node_or_null("%RerollButton") as Button
@onready var reroll_label: Label = get_node_or_null("%RerollLabel") as Label

var current_choices: Array = []
var is_accepting_input := false
var _showing_ship_modules := false
var _previewing_weapon := false
var _weapon_loadout: PlayerWeaponLoadout
var _reroll_enabled := false


func _ready() -> void:
	for index in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
		choice_buttons[index].focus_entered.connect(_highlight_choice.bind(index))
		choice_buttons[index].mouse_entered.connect(_highlight_choice.bind(index))
	offer_ship_panel.facility_selected.connect(_on_facility_selected)
	if reroll_button != null:
		reroll_button.pressed.connect(_on_reroll_pressed)
	visible = false


func configure_player_registry(registry: PlayerAugmentRegistry) -> void:
	offer_ship_panel.set_registry(registry)


func configure_weapon_loadout(loadout: PlayerWeaponLoadout) -> void:
	_weapon_loadout = loadout
	if is_node_ready():
		offer_weapon_preview.set_loadout(loadout)


func open_choices(
	title: String,
	prompt: String,
	choices: Array,
	accent_color: Color,
	show_ship_modules: bool = false,
) -> void:
	_set_input_enabled(false)
	_set_choices(choices)
	_showing_ship_modules = show_ship_modules
	_set_ship_section_visible(show_ship_modules)
	accent_bar.color = accent_color
	_set_choice_buttons_visible(false)

	visible = true
	choice_container.visible = false
	backdrop.modulate.a = 0.0
	var backdrop_tween := _create_pause_tween()
	backdrop_tween.tween_property(backdrop, "modulate:a", 1.0, open_duration)
	await breakpoint_intro.play_intro(accent_color)

	choice_container.visible = true
	title_label.text = title
	prompt_label.text = prompt
	_set_choice_buttons_visible(true)
	panel_container.modulate.a = 0.0
	panel_container.scale = Vector2(0.96, 0.96)
	panel_container.pivot_offset = panel_container.size * 0.5
	content_container.modulate.a = 1.0

	var open_tween := _create_pause_tween().set_parallel(true)
	open_tween.tween_property(panel_container, "modulate:a", 1.0, open_duration)
	open_tween.tween_property(panel_container, "scale", Vector2.ONE, open_duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	await open_tween.finished
	_set_input_enabled(true)
	choice_buttons[0].grab_focus()
	_highlight_choice(0)


func close_with_result(result_title: String, augment: Resource, accent_color: Color) -> void:
	await _close_with_summary(result_title, str(augment.get("display_name")), accent_color)


func close_with_text(result_title: String, result_text: String, accent_color: Color) -> void:
	await _close_with_summary(result_title, result_text, accent_color)


func suspend_choices() -> void:
	_set_input_enabled(false)
	breakpoint_intro.visible = false
	visible = false


func resume_choices() -> void:
	visible = true
	choice_container.visible = true
	breakpoint_intro.visible = false
	panel_container.modulate.a = 1.0
	panel_container.scale = Vector2.ONE
	content_container.modulate.a = 1.0
	_set_choice_buttons_visible(true)
	_set_input_enabled(true)
	choice_buttons[0].grab_focus()
	_highlight_choice(0)


func refresh_choices(choices: Array) -> void:
	_set_choices(choices)
	_set_choice_buttons_visible(true)
	if is_accepting_input and not choice_buttons.is_empty():
		choice_buttons[0].grab_focus()
		_highlight_choice(0)


func set_reroll_state(remaining: int, enabled: bool) -> void:
	## Pass remaining < 0 to hide the reroll row (enemy offers).
	var show_row := remaining >= 0
	_reroll_enabled = show_row and enabled and remaining > 0
	if reroll_label != null:
		reroll_label.visible = show_row
		if show_row:
			reroll_label.text = "[R] 리롤 · 남은 횟수 %d" % maxi(0, remaining)
			reroll_label.modulate = (
				Color(1, 1, 1, 1) if _reroll_enabled else Color(0.55, 0.55, 0.6, 0.85)
			)
	if reroll_button != null:
		reroll_button.visible = show_row
		reroll_button.disabled = not _reroll_enabled
		if show_row:
			reroll_button.text = "리롤 (%d)" % maxi(0, remaining)


func _on_reroll_pressed() -> void:
	if not is_accepting_input or not _reroll_enabled:
		return
	reroll_requested.emit()


func restore_for_result() -> void:
	visible = true
	choice_container.visible = true
	breakpoint_intro.visible = false
	panel_container.modulate.a = 1.0
	panel_container.scale = Vector2.ONE
	content_container.modulate.a = 1.0
	_set_input_enabled(false)


func hide_choices() -> void:
	suspend_choices()
	current_choices.clear()


func _close_with_summary(result_title: String, result_text: String, accent_color: Color) -> void:
	_set_input_enabled(false)
	await _fade_content(0.0, phase_transition_duration * 0.75)
	current_choices.clear()
	_set_choice_buttons_visible(false)
	_set_ship_section_visible(false)
	title_label.text = result_title
	prompt_label.text = result_text
	accent_bar.color = accent_color
	await _fade_content(1.0, phase_transition_duration)
	await _wait(result_hold_duration)

	var close_tween := _create_pause_tween().set_parallel(true)
	close_tween.tween_property(backdrop, "modulate:a", 0.0, close_duration)
	close_tween.tween_property(panel_container, "modulate:a", 0.0, close_duration)
	close_tween.tween_property(panel_container, "scale", Vector2(0.97, 0.97), close_duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	await close_tween.finished
	visible = false
	panel_container.scale = Vector2.ONE
	panel_container.modulate.a = 1.0
	content_container.modulate.a = 1.0


func _set_choices(choices: Array) -> void:
	assert(not choices.is_empty(), "AugmentSelectionOverlay requires at least one choice.")
	assert(choices.size() <= choice_buttons.size(), "AugmentSelectionOverlay supports up to three choices.")
	current_choices = choices.duplicate()

	for index in choice_buttons.size():
		var button := choice_buttons[index]
		if index >= current_choices.size():
			button.visible = false
			continue
		var augment := current_choices[index] as Resource
		var player_augment := augment as PlayerAugment
		var icon_max_width := CHOICE_ICON_MAX_WIDTH
		if player_augment != null:
			button.text = "%s\n%s" % [
				player_augment.get_offer_title(_weapon_loadout),
				player_augment.get_offer_description(_weapon_loadout),
			]
			button.icon = player_augment.get_offer_icon()
		else:
			button.text = "%s\n%s" % [augment.get("display_name"), augment.get("description")]
			button.icon = augment.get("icon") as Texture2D
			icon_max_width = ENEMY_CHOICE_ICON_MAX_WIDTH
		button.add_theme_constant_override("icon_max_width", icon_max_width)
		button.visible = true


func _set_ship_section_visible(section_visible: bool) -> void:
	ship_separator.visible = section_visible
	slot_action_label.visible = section_visible
	offer_ship_panel.visible = section_visible
	offer_weapon_preview.visible = false
	_previewing_weapon = false


func _highlight_choice(index: int) -> void:
	if not _showing_ship_modules or index < 0 or index >= current_choices.size():
		return
	var augment := current_choices[index] as PlayerAugment
	if augment == null:
		return
	var is_weapon_offer := PlayerAugmentKind.is_weapon_offer(augment.augment_type)
	_previewing_weapon = is_weapon_offer
	ship_separator.visible = true
	slot_action_label.visible = true
	offer_ship_panel.visible = not is_weapon_offer
	offer_weapon_preview.visible = is_weapon_offer
	offer_ship_panel.set_selection_input_enabled(is_accepting_input and not is_weapon_offer)
	if is_weapon_offer:
		slot_action_label.text = "병기 배치 · 적용 대상 미리보기"
		offer_weapon_preview.set_loadout(_weapon_loadout)
		offer_weapon_preview.show_augment(augment)
	else:
		slot_action_label.text = "시설을 선택하면 빈 슬롯 +1 · 최대 3"
		offer_ship_panel.set_expansion_preview_facility(&"")
		offer_ship_panel.set_highlighted_facility(augment.facility_id)
	if is_accepting_input:
		_configure_focus_navigation()


func _on_choice_pressed(index: int) -> void:
	if not is_accepting_input:
		return
	if index < 0 or index >= current_choices.size():
		return
	_set_input_enabled(false)
	choice_selected.emit(current_choices[index] as Resource)


func _on_facility_selected(facility_id: StringName) -> void:
	if not is_accepting_input or not _showing_ship_modules:
		return
	_set_input_enabled(false)
	facility_expansion_selected.emit(facility_id)


func _set_choice_buttons_visible(buttons_visible: bool) -> void:
	for index in choice_buttons.size():
		choice_buttons[index].visible = buttons_visible and index < current_choices.size()


func _set_input_enabled(enabled: bool) -> void:
	is_accepting_input = enabled
	for button in choice_buttons:
		button.disabled = not enabled
	offer_ship_panel.set_selection_input_enabled(
		enabled and _showing_ship_modules and not _previewing_weapon
	)
	if reroll_button != null:
		reroll_button.disabled = not enabled or not _reroll_enabled
	if enabled:
		_configure_focus_navigation()


func _configure_focus_navigation() -> void:
	var visible_buttons: Array[Button] = []
	for button in choice_buttons:
		if button.visible and not button.disabled:
			visible_buttons.append(button)
	var modules: Array[ShipFacilityModule] = []
	if offer_ship_panel.visible:
		modules = offer_ship_panel.get_selectable_modules()
	var module_by_id: Dictionary = {}
	for module in modules:
		module_by_id[module.facility_id] = module

	var all_controls: Array[Control] = []
	for button in visible_buttons:
		all_controls.append(button)
	for module in modules:
		all_controls.append(module)
	for control in all_controls:
		_clear_focus_neighbors(control)

	for index in visible_buttons.size():
		var button := visible_buttons[index]
		_set_focus_neighbor(button, "focus_neighbor_left", visible_buttons[maxi(0, index - 1)])
		_set_focus_neighbor(
			button,
			"focus_neighbor_right",
			visible_buttons[mini(visible_buttons.size() - 1, index + 1)],
		)
		if _showing_ship_modules:
			var augment := current_choices[index] as PlayerAugment
			if augment != null and not PlayerAugmentKind.is_weapon_offer(augment.augment_type):
				var target := module_by_id.get(augment.facility_id) as ShipFacilityModule
				if target == null:
					var fallback_column: int = 0 if index * 2 < visible_buttons.size() else 1
					target = _first_module_in_column(module_by_id, fallback_column)
				_set_focus_neighbor(button, "focus_neighbor_bottom", target)

	for row in FACILITY_GRID.size():
		for column in FACILITY_GRID[row].size():
			var module := module_by_id.get(FACILITY_GRID[row][column]) as ShipFacilityModule
			if module == null:
				continue
			var horizontal_column: int = 1 - column
			var horizontal := module_by_id.get(FACILITY_GRID[row][horizontal_column]) as ShipFacilityModule
			_set_focus_neighbor(
				module,
				"focus_neighbor_left" if column == 1 else "focus_neighbor_right",
				horizontal,
			)
			var above: Control = _next_module_in_column(module_by_id, column, row, -1)
			if above == null and not visible_buttons.is_empty():
				above = visible_buttons[0 if column == 0 else visible_buttons.size() - 1]
			_set_focus_neighbor(module, "focus_neighbor_top", above)
			var below := _next_module_in_column(module_by_id, column, row, 1)
			_set_focus_neighbor(module, "focus_neighbor_bottom", below if below != null else module)

	for index in all_controls.size():
		var previous := all_controls[(index - 1 + all_controls.size()) % all_controls.size()]
		var next := all_controls[(index + 1) % all_controls.size()]
		_set_focus_neighbor(all_controls[index], "focus_previous", previous)
		_set_focus_neighbor(all_controls[index], "focus_next", next)


func _first_module_in_column(module_by_id: Dictionary, column: int) -> ShipFacilityModule:
	for row in FACILITY_GRID.size():
		var module := module_by_id.get(FACILITY_GRID[row][column]) as ShipFacilityModule
		if module != null:
			return module
	return null


func _next_module_in_column(
	module_by_id: Dictionary,
	column: int,
	start_row: int,
	direction: int,
) -> ShipFacilityModule:
	var row := start_row + direction
	while row >= 0 and row < FACILITY_GRID.size():
		var module := module_by_id.get(FACILITY_GRID[row][column]) as ShipFacilityModule
		if module != null:
			return module
		row += direction
	return null


func _clear_focus_neighbors(control: Control) -> void:
	control.focus_neighbor_left = NodePath()
	control.focus_neighbor_top = NodePath()
	control.focus_neighbor_right = NodePath()
	control.focus_neighbor_bottom = NodePath()
	control.focus_next = NodePath()
	control.focus_previous = NodePath()


func _set_focus_neighbor(control: Control, property_name: String, target: Control) -> void:
	if target == null:
		return
	control.set(property_name, control.get_path_to(target))


func _fade_content(target_alpha: float, duration: float) -> void:
	var tween := _create_pause_tween()
	tween.tween_property(content_container, "modulate:a", target_alpha, duration)
	await tween.finished


func _wait(duration: float) -> void:
	if duration <= 0.0:
		return
	var tween := _create_pause_tween()
	tween.tween_interval(duration)
	await tween.finished


func _create_pause_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _unhandled_input(event: InputEvent) -> void:
	if not is_accepting_input or not _reroll_enabled or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_R or key.physical_keycode == KEY_R:
			_on_reroll_pressed()
			get_viewport().set_input_as_handled()
