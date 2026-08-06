class_name AugmentSelectionOverlay
extends CanvasLayer

signal choice_selected(choice: Resource)
signal universal_slot_expansion_selected
signal reroll_requested(choice_index: int)

const CHOICE_ICON_MAX_WIDTH := 28
const ENEMY_CHOICE_ICON_MAX_WIDTH := 48
const CHOICE_CARD_SIZE := Vector2(156.0, 188.0)
const CAROUSEL_SIDE_OFFSET := 32.0
const CAROUSEL_SIDE_DROP := 10.0
const CAROUSEL_SIDE_SCALE := Vector2(0.84, 0.84)
const CAROUSEL_SIDE_MODULATE := Color(0.5, 0.58, 0.7, 0.5)
const CAROUSEL_FOCUS_MODULATE := Color.WHITE
## Initial hold delay before continuous rotation starts.
const CAROUSEL_HOLD_DELAY := 0.35

@export var player_accent_color: Color
@export var enemy_accent_color: Color
@export_range(0.01, 5.0, 0.01) var open_duration := 0.2
@export_range(0.01, 1.0, 0.01) var carousel_transition_duration := 0.28
## Minimum time between rotation starts. Hold-repeat never exceeds this rate.
@export_range(0.1, 5.0, 0.01) var carousel_min_rotation_interval := 0.45
@export_range(0.01, 5.0, 0.01) var phase_transition_duration := 0.5
@export_range(0.0, 5.0, 0.01) var result_hold_duration := 2.5
@export_range(0.01, 5.0, 0.01) var close_duration := 0.22

@onready var backdrop: ColorRect = $Backdrop
@onready var breakpoint_intro: AugmentBreakpointIntro = $BreakpointIntro
@onready var choice_container: MarginContainer = $MarginContainer
@onready var panel_container: PanelContainer = $MarginContainer/PanelContainer
@onready var content_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer
@onready var accent_bar: ColorRect = $MarginContainer/PanelContainer/VBoxContainer/AccentBar
@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var slot_action_label: Button = %SlotActionLabel
@onready var choice_carousel: Control = %ChoiceCarousel
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
var _weapon_loadout: PlayerWeaponLoadout
var _player_registry: PlayerAugmentRegistry
var _status_ship_panel: ShipPanel
var _status_weapon_hud: WeaponLoadoutHud
var _reroll_enabled := false
var _focused_choice_index := 0
var _carousel_tween: Tween
var _held_rotation_direction := 0
var _hold_repeat_remaining := 0.0
var _rotation_cooldown_remaining := 0.0
var _carousel_rotating := false


func _ready() -> void:
	for index in choice_buttons.size():
		choice_buttons[index].custom_minimum_size = CHOICE_CARD_SIZE
		choice_buttons[index].size = CHOICE_CARD_SIZE
		choice_buttons[index].pivot_offset = CHOICE_CARD_SIZE * 0.5
		choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
		choice_buttons[index].focus_entered.connect(_highlight_choice.bind(index))
		choice_buttons[index].mouse_entered.connect(_highlight_choice.bind(index))
	slot_action_label.pressed.connect(_on_expand_slot_pressed)
	slot_action_label.focus_entered.connect(_refresh_expansion_preview)
	slot_action_label.focus_exited.connect(_queue_expansion_preview_refresh)
	slot_action_label.mouse_entered.connect(_refresh_expansion_preview)
	slot_action_label.mouse_exited.connect(_queue_expansion_preview_refresh)
	if reroll_button != null:
		reroll_button.pressed.connect(_on_reroll_pressed)
	visible = false
	call_deferred("_layout_choice_cards", false)


func configure_player_registry(registry: PlayerAugmentRegistry) -> void:
	_player_registry = registry


func configure_weapon_loadout(loadout: PlayerWeaponLoadout) -> void:
	_weapon_loadout = loadout


func configure_status_preview(ship_panel: ShipPanel, weapon_hud: WeaponLoadoutHud) -> void:
	_status_ship_panel = ship_panel
	_status_weapon_hud = weapon_hud
	_clear_status_preview()


func open_choices(
	title: String,
	choices: Array,
	accent_color: Color,
	show_ship_modules: bool = false,
) -> void:
	_set_input_enabled(false)
	_set_choices(choices)
	_focused_choice_index = 0
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
	prompt_label.text = ""
	prompt_label.visible = false
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
	_clear_status_preview()
	breakpoint_intro.visible = false
	visible = false


func resume_choices() -> void:
	visible = true
	choice_container.visible = true
	breakpoint_intro.visible = false
	prompt_label.visible = false
	panel_container.modulate.a = 1.0
	panel_container.scale = Vector2.ONE
	content_container.modulate.a = 1.0
	_set_choice_buttons_visible(true)
	_set_input_enabled(true)
	var focus_index := clampi(_focused_choice_index, 0, current_choices.size() - 1)
	choice_buttons[focus_index].grab_focus()
	_highlight_choice(focus_index)


func refresh_choices(choices: Array) -> void:
	_set_choices(choices)
	_focused_choice_index = clampi(_focused_choice_index, 0, current_choices.size() - 1)
	_set_choice_buttons_visible(true)
	if is_accepting_input and not choice_buttons.is_empty():
		choice_buttons[_focused_choice_index].grab_focus()
		_highlight_choice(_focused_choice_index)


func refresh_choice_at(index: int, choice: PlayerAugment) -> void:
	if index < 0 or index >= current_choices.size() or choice == null:
		return
	current_choices[index] = choice
	_populate_choice_button(index)
	var button := choice_buttons[index]
	var target_modulate := _get_choice_target_modulate(index)
	button.modulate = Color(target_modulate.r, target_modulate.g, target_modulate.b, 0.0)
	var tween := _create_pause_tween()
	tween.tween_property(button, "modulate", target_modulate, carousel_transition_duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_refresh_status_preview()


func set_reroll_state(remaining: int, enabled: bool) -> void:
	## Pass remaining < 0 to hide the reroll row (enemy offers).
	var show_row := remaining >= 0
	_reroll_enabled = show_row and enabled and remaining > 0
	if reroll_label != null:
		reroll_label.visible = false
	if reroll_button != null:
		reroll_button.visible = show_row
		reroll_button.disabled = not _reroll_enabled
		if show_row:
			reroll_button.text = "[R] 리롤 (%d)" % maxi(0, remaining)
	if is_accepting_input:
		_configure_focus_navigation()


func _on_reroll_pressed() -> void:
	if not is_accepting_input or not _reroll_enabled:
		return
	reroll_requested.emit(_focused_choice_index)


func restore_for_result() -> void:
	_clear_status_preview()
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
	_clear_status_preview()
	await _fade_content(0.0, phase_transition_duration * 0.75)
	current_choices.clear()
	_set_choice_buttons_visible(false)
	_set_ship_section_visible(false)
	title_label.text = result_title
	prompt_label.text = result_text
	prompt_label.visible = true
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
		_populate_choice_button(index)
		button.visible = true
	_layout_choice_cards(false)


func _populate_choice_button(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	var button := choice_buttons[index]
	var augment := current_choices[index] as Resource
	var player_augment := augment as PlayerAugment
	var icon_max_width := CHOICE_ICON_MAX_WIDTH
	if player_augment != null:
		button.text = "%s\n\n%s" % [
			player_augment.get_offer_title(_weapon_loadout),
			player_augment.get_offer_description(_weapon_loadout),
		]
		button.icon = player_augment.get_offer_icon()
	else:
		button.text = "%s\n\n%s" % [augment.get("display_name"), augment.get("description")]
		button.icon = augment.get("icon") as Texture2D
		icon_max_width = ENEMY_CHOICE_ICON_MAX_WIDTH
	button.add_theme_constant_override("icon_max_width", icon_max_width)


func _set_ship_section_visible(section_visible: bool) -> void:
	if not section_visible:
		_clear_status_preview()
	slot_action_label.visible = section_visible


func _highlight_choice(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	var focus_changed := _focused_choice_index != index
	_focused_choice_index = index
	_layout_choice_cards(focus_changed and visible)
	_refresh_status_preview()


func _refresh_status_preview() -> void:
	if not _showing_ship_modules or _focused_choice_index < 0 or _focused_choice_index >= current_choices.size():
		_clear_status_preview()
		return
	var index := _focused_choice_index
	var augment := current_choices[index] as PlayerAugment
	if augment == null:
		_clear_status_preview()
		return
	var is_weapon_offer := PlayerAugmentKind.is_weapon_offer(augment.augment_type)
	slot_action_label.visible = true
	_refresh_slot_expansion_action()
	if is_weapon_offer:
		if _status_ship_panel != null:
			_status_ship_panel.set_highlighted_facility(&"")
			_status_ship_panel.set_augment_preview(null)
		if _status_weapon_hud != null:
			_status_weapon_hud.show_augment_preview(augment)
	else:
		if _status_weapon_hud != null:
			_status_weapon_hud.clear_augment_preview()
		if _status_ship_panel != null:
			_status_ship_panel.set_highlighted_facility(augment.get_primary_module_tag())
			_status_ship_panel.set_augment_preview(augment)
	_refresh_expansion_preview()
	if is_accepting_input:
		_configure_focus_navigation()


func _refresh_slot_expansion_action() -> void:
	var capacity := _player_registry.get_slot_capacity() if _player_registry != null else 0
	var can_expand := _player_registry != null and _player_registry.can_expand_slots()
	if can_expand:
		slot_action_label.text = "스킵 후 범용 슬롯 확장 %d → %d" % [
			capacity,
			capacity + 1,
		]
	else:
		slot_action_label.text = "스킵 (범용 슬롯 MAX 도달)"
	slot_action_label.disabled = (
		not is_accepting_input
		or _player_registry == null
		or not can_expand
	)


func _clear_status_preview() -> void:
	if _status_ship_panel != null:
		_status_ship_panel.set_highlighted_facility(&"")
		_status_ship_panel.set_expansion_preview(false)
		_status_ship_panel.set_augment_preview(null)
	if _status_weapon_hud != null:
		_status_weapon_hud.clear_augment_preview()


func _on_choice_pressed(index: int) -> void:
	if not is_accepting_input:
		return
	if index < 0 or index >= current_choices.size():
		return
	if index != _focused_choice_index:
		choice_buttons[index].grab_focus()
		if _focused_choice_index != index:
			_highlight_choice(index)
		return
	_set_input_enabled(false)
	choice_selected.emit(current_choices[index] as Resource)


func _on_expand_slot_pressed() -> void:
	if not is_accepting_input or not _showing_ship_modules:
		return
	if _status_ship_panel != null:
		_status_ship_panel.set_expansion_preview(false)
	_set_input_enabled(false)
	universal_slot_expansion_selected.emit()


func _set_choice_buttons_visible(buttons_visible: bool) -> void:
	for index in choice_buttons.size():
		choice_buttons[index].visible = buttons_visible and index < current_choices.size()
	_layout_choice_cards(false)


func _set_input_enabled(enabled: bool) -> void:
	is_accepting_input = enabled
	if not enabled:
		_clear_carousel_hold_state()
	for button in choice_buttons:
		button.disabled = not enabled
	if _showing_ship_modules:
		_refresh_slot_expansion_action()
	else:
		slot_action_label.disabled = true
	_refresh_expansion_preview()
	if reroll_button != null:
		reroll_button.disabled = not enabled or not _reroll_enabled
	if enabled:
		_configure_focus_navigation()


func _refresh_expansion_preview() -> void:
	if _status_ship_panel == null:
		return
	var pointer_inside := (
		slot_action_label.visible
		and slot_action_label.get_global_rect().has_point(slot_action_label.get_viewport().get_mouse_position())
	)
	var expansion_enabled := (
		not slot_action_label.disabled
		and (slot_action_label.has_focus() or pointer_inside)
	)
	if expansion_enabled:
		_status_ship_panel.set_augment_preview(null)
	_status_ship_panel.set_expansion_preview(expansion_enabled)
	if not expansion_enabled:
		var augment := _get_focused_player_augment()
		if augment != null and not PlayerAugmentKind.is_weapon_offer(augment.augment_type):
			_status_ship_panel.set_augment_preview(augment)


func _queue_expansion_preview_refresh() -> void:
	call_deferred("_refresh_expansion_preview")


func _configure_focus_navigation() -> void:
	var visible_buttons: Array[Button] = []
	for button in choice_buttons:
		if button.visible and not button.disabled:
			visible_buttons.append(button)

	var all_controls: Array[Control] = []
	for button in visible_buttons:
		all_controls.append(button)
	var can_focus_reroll := reroll_button != null and reroll_button.visible and not reroll_button.disabled
	if can_focus_reroll:
		all_controls.append(reroll_button)
	var can_focus_expansion := slot_action_label.visible and not slot_action_label.disabled
	if can_focus_expansion:
		all_controls.append(slot_action_label)
	for control in all_controls:
		_clear_focus_neighbors(control)

	# Horizontal focus neighbors stay empty so Godot never auto-jumps cards
	# on ui_left/ui_right. Carousel owns left/right exclusively.
	for button in visible_buttons:
		_set_focus_neighbor(button, "focus_neighbor_left", button)
		_set_focus_neighbor(button, "focus_neighbor_right", button)
		var first_action: Control = null
		if can_focus_reroll:
			first_action = reroll_button
		elif can_focus_expansion:
			first_action = slot_action_label
		if first_action != null:
			_set_focus_neighbor(button, "focus_neighbor_bottom", first_action)
		var last_action: Control = null
		if can_focus_expansion:
			last_action = slot_action_label
		elif can_focus_reroll:
			last_action = reroll_button
		if last_action != null:
			_set_focus_neighbor(button, "focus_neighbor_top", last_action)
	var focused_card: Button = null
	if not visible_buttons.is_empty():
		focused_card = choice_buttons[clampi(_focused_choice_index, 0, current_choices.size() - 1)]
	if can_focus_reroll and focused_card != null:
		_set_focus_neighbor(
			reroll_button,
			"focus_neighbor_top",
			focused_card,
		)
		_set_focus_neighbor(
			reroll_button,
			"focus_neighbor_bottom",
			slot_action_label if can_focus_expansion else focused_card,
		)
	if can_focus_expansion and focused_card != null:
		_set_focus_neighbor(
			slot_action_label,
			"focus_neighbor_top",
			reroll_button if can_focus_reroll else focused_card,
		)
		_set_focus_neighbor(slot_action_label, "focus_neighbor_bottom", focused_card)

	# Tab cycles only among the vertical action chain + focused card, never
	# across the three carousel cards as a left/right ring.
	var tab_controls: Array[Control] = []
	if focused_card != null:
		tab_controls.append(focused_card)
	if can_focus_reroll:
		tab_controls.append(reroll_button)
	if can_focus_expansion:
		tab_controls.append(slot_action_label)
	for index in tab_controls.size():
		var previous := tab_controls[(index - 1 + tab_controls.size()) % tab_controls.size()]
		var next := tab_controls[(index + 1) % tab_controls.size()]
		_set_focus_neighbor(tab_controls[index], "focus_previous", previous)
		_set_focus_neighbor(tab_controls[index], "focus_next", next)


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


func _layout_choice_cards(animated: bool = true) -> void:
	if choice_carousel == null:
		return
	if _carousel_tween != null:
		_carousel_tween.kill()
		_carousel_tween = null
	if not animated:
		_carousel_rotating = false
	var center := Vector2(
		maxf(0.0, (choice_carousel.size.x - CHOICE_CARD_SIZE.x) * 0.5),
		4.0,
	)
	if animated:
		_carousel_rotating = true
		_carousel_tween = _create_pause_tween().set_parallel(true)
	for index in choice_buttons.size():
		var button := choice_buttons[index]
		if index >= current_choices.size():
			continue
		var relative_slot := _get_relative_slot(index)
		var target_position := center
		var target_scale := Vector2.ONE
		var target_modulate := CAROUSEL_FOCUS_MODULATE
		var target_z := 20
		if relative_slot < 0:
			target_position += Vector2(-CAROUSEL_SIDE_OFFSET, CAROUSEL_SIDE_DROP)
			target_scale = CAROUSEL_SIDE_SCALE
			target_modulate = CAROUSEL_SIDE_MODULATE
			target_z = 10
		elif relative_slot > 0:
			target_position += Vector2(CAROUSEL_SIDE_OFFSET, CAROUSEL_SIDE_DROP)
			target_scale = CAROUSEL_SIDE_SCALE
			target_modulate = CAROUSEL_SIDE_MODULATE
			target_z = 10
		button.z_index = target_z
		if animated:
			_carousel_tween.tween_property(
				button,
				"position",
				target_position,
				carousel_transition_duration,
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			_carousel_tween.tween_property(
				button,
				"scale",
				target_scale,
				carousel_transition_duration,
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			_carousel_tween.tween_property(
				button,
				"modulate",
				target_modulate,
				carousel_transition_duration,
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		else:
			button.position = target_position
			button.scale = target_scale
			button.modulate = target_modulate
	if animated and _carousel_tween != null:
		_carousel_tween.finished.connect(_on_carousel_tween_finished)


func _get_relative_slot(index: int) -> int:
	var count := current_choices.size()
	if count <= 1 or index == _focused_choice_index:
		return 0
	var clockwise := posmod(index - _focused_choice_index, count)
	if count == 2:
		return 1
	return 1 if clockwise == 1 else -1


func _get_choice_target_modulate(index: int) -> Color:
	return CAROUSEL_FOCUS_MODULATE if index == _focused_choice_index else CAROUSEL_SIDE_MODULATE


func _can_start_carousel_rotation() -> bool:
	return (
		is_accepting_input
		and visible
		and current_choices.size() >= 2
		and not _carousel_rotating
		and _rotation_cooldown_remaining <= 0.0
		and _choice_card_has_keyboard_focus()
	)


func _try_start_carousel_rotation(direction: int) -> bool:
	direction = signi(direction)
	if direction == 0 or not _can_start_carousel_rotation():
		return false
	_rotate_carousel(direction)
	return true


func _rotate_carousel(direction: int) -> void:
	_carousel_rotating = true
	_rotation_cooldown_remaining = carousel_min_rotation_interval
	var next_index := posmod(_focused_choice_index + direction, current_choices.size())
	choice_buttons[next_index].grab_focus()
	if _focused_choice_index != next_index:
		_highlight_choice(next_index)
	else:
		_carousel_rotating = false


func _on_carousel_tween_finished() -> void:
	_carousel_tween = null
	_carousel_rotating = false


func _clear_carousel_hold_state() -> void:
	_held_rotation_direction = 0
	_hold_repeat_remaining = 0.0
	_rotation_cooldown_remaining = 0.0


func _choice_card_has_keyboard_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	for button in choice_buttons:
		if focus_owner == button:
			return true
	return false


func get_focused_choice_index() -> int:
	return _focused_choice_index


func _get_focused_player_augment() -> PlayerAugment:
	if _focused_choice_index < 0 or _focused_choice_index >= current_choices.size():
		return null
	return current_choices[_focused_choice_index] as PlayerAugment


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


func _process(delta: float) -> void:
	if _rotation_cooldown_remaining > 0.0:
		_rotation_cooldown_remaining = maxf(0.0, _rotation_cooldown_remaining - delta)
	if _held_rotation_direction == 0 or not is_accepting_input or not visible:
		return
	_hold_repeat_remaining -= delta
	if _hold_repeat_remaining > 0.0:
		return
	# Only rotate while the key is still held. Never queue a step for after release.
	if _try_start_carousel_rotation(_held_rotation_direction):
		_hold_repeat_remaining = carousel_min_rotation_interval
	else:
		# Keep polling until cooldown allows the next step, or the key is released.
		_hold_repeat_remaining = 0.05


func _input(event: InputEvent) -> void:
	if not is_accepting_input or not visible:
		return
	var direction := 0
	# allow_echo=false: OS key-repeat must not start extra rotations.
	if event.is_action_pressed(&"ui_left", false):
		direction = -1
	elif event.is_action_pressed(&"ui_right", false):
		direction = 1
	if direction != 0:
		# Swallow left/right completely so Button focus neighbors never steal them.
		_held_rotation_direction = direction
		_hold_repeat_remaining = CAROUSEL_HOLD_DELAY
		_try_start_carousel_rotation(direction)
		get_viewport().set_input_as_handled()
		return
	var released_left := event.is_action_released(&"ui_left")
	var released_right := event.is_action_released(&"ui_right")
	if (
		(released_left and _held_rotation_direction < 0)
		or (released_right and _held_rotation_direction > 0)
	):
		_held_rotation_direction = 0
		_hold_repeat_remaining = 0.0
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_accepting_input or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _reroll_enabled and (key.keycode == KEY_R or key.physical_keycode == KEY_R):
			_on_reroll_pressed()
			get_viewport().set_input_as_handled()
