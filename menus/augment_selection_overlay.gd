class_name AugmentSelectionOverlay
extends CanvasLayer

## 증강 선택 무대. 카드 3장을 가로로 나란히 두고 우측 STATUS를 미리보기로 쓴다.
## 규칙: docs/design/augments.md (UI 요약)

signal choice_selected(choice: Resource)
signal universal_slot_expansion_selected
signal reroll_requested(choice_index: int)

const CHOICE_CARD_SIZE := Vector2(140.0, 188.0)
const CARD_GAP := 12.0
## 카드 행 안에서 포커스되지 않은 카드의 윗변 위치. 포커스 카드는 FOCUS_LIFT만큼 떠오른다.
const CARD_TOP := 12.0
const FOCUS_LIFT := 8.0
const UNFOCUSED_SCALE := Vector2(0.94, 0.94)
## Keep copy readable on every card; the surface shader, lift and scale mark focus.
const UNFOCUSED_MODULATE := Color.WHITE
const FOCUSED_MODULATE := Color.WHITE
const ENTRANCE_DROP := 16.0
const RESULT_DROP := 14.0
const CARD_SCENES := [
	preload("res://menus/cards/augment_card_silver.tscn"),
	preload("res://menus/cards/augment_card_gold.tscn"),
	preload("res://menus/cards/augment_card_prismatic.tscn"),
]
const ENEMY_CARD_SCENE := preload("res://menus/cards/augment_card_enemy.tscn")
## 아이콘이 없는 적 증강 카드에 쓰는 공용 경고 아이콘.
const ENEMY_FALLBACK_ICON := preload("res://assets/ui/threat.svg")
const ENEMY_TITLE_COLOR := Color(1.0, 0.78, 0.84)
const TIER_TAG_COLORS := {
	PlayerAugment.Tier.SILVER: Color(0.75, 0.9, 1.0),
	PlayerAugment.Tier.GOLD: Color(1.0, 0.79, 0.28),
	PlayerAugment.Tier.PRISMATIC: Color(1.0, 0.58, 0.96),
}
const CARD_HINT := "←→ 선택 · Enter 결정"

@export var player_accent_color: Color
@export var enemy_accent_color: Color
@export_range(0.01, 5.0, 0.01) var open_duration := 0.2
@export_range(0.01, 1.0, 0.01) var focus_transition_duration := 0.15
@export_range(0.01, 5.0, 0.01) var phase_transition_duration := 0.5
@export_range(0.0, 5.0, 0.01) var result_hold_duration := 2.5
@export_range(0.01, 5.0, 0.01) var close_duration := 0.22

@onready var stage: Control = $Stage
@onready var backdrop: ColorRect = $Stage/Backdrop
@onready var breakpoint_intro: AugmentBreakpointIntro = $Stage/BreakpointIntro
@onready var choice_container: Control = $Stage/Content
@onready var tag_label: Label = %TagLabel
@onready var title_label: Label = %TitleLabel
@onready var accent_bar: ColorRect = %AccentBar
@onready var choice_row: Control = %ChoiceRow
@onready var prompt_label: Label = %PromptLabel
@onready var action_row: HBoxContainer = %ActionRow
@onready var reroll_button: Button = %RerollButton
@onready var slot_action_label: Button = %SlotActionLabel
@onready var hint_label: Label = %HintLabel
@onready var choice_buttons: Array[Button] = [
	%ChoiceButton1,
	%ChoiceButton2,
	%ChoiceButton3,
]

var current_choices: Array = []
var is_accepting_input := false
var _showing_ship_modules := false
var _weapon_loadout: PlayerWeaponLoadout
var _player_registry: PlayerAugmentRegistry
var _status_ship_panel: ShipPanel
var _status_weapon_hud: WeaponLoadoutHud
## 무대 오른쪽 끝이 되는 Control(우측 STATUS 패널). 없으면 화면 전체가 무대다.
var _stage_limit: Control
var _reroll_enabled := false
var _focused_choice_index := 0
## 결정한 카드. 슬롯 확장처럼 카드를 고르지 않았으면 -1.
var _selected_index := -1
var _showing_result := false
var _layout_tween: Tween


func _ready() -> void:
	for index in choice_buttons.size():
		var button := choice_buttons[index]
		button.custom_minimum_size = CHOICE_CARD_SIZE
		button.size = CHOICE_CARD_SIZE
		button.pivot_offset = CHOICE_CARD_SIZE * 0.5
		button.pressed.connect(_on_choice_pressed.bind(index))
		button.focus_entered.connect(_highlight_choice.bind(index))
		button.mouse_entered.connect(_on_control_hovered.bind(button))
	slot_action_label.pressed.connect(_on_expand_slot_pressed)
	slot_action_label.focus_entered.connect(_refresh_expansion_preview)
	slot_action_label.focus_exited.connect(_queue_expansion_preview_refresh)
	slot_action_label.mouse_entered.connect(_on_control_hovered.bind(slot_action_label))
	slot_action_label.mouse_exited.connect(_queue_expansion_preview_refresh)
	reroll_button.pressed.connect(_on_reroll_pressed)
	reroll_button.mouse_entered.connect(_on_control_hovered.bind(reroll_button))
	choice_row.resized.connect(_on_choice_row_resized)
	visible = false
	_layout_choice_cards.call_deferred(false)


func configure_player_registry(registry: PlayerAugmentRegistry) -> void:
	_player_registry = registry


func configure_weapon_loadout(loadout: PlayerWeaponLoadout) -> void:
	_weapon_loadout = loadout


func configure_status_preview(ship_panel: ShipPanel, weapon_hud: WeaponLoadoutHud) -> void:
	_status_ship_panel = ship_panel
	_status_weapon_hud = weapon_hud
	_clear_status_preview()


## 무대를 이 Control의 왼쪽 끝까지로 제한한다(우측 STATUS를 덮지 않음).
func configure_stage_limit(limit: Control) -> void:
	_stage_limit = limit
	_apply_stage_rect()


func open_choices(
	title: String,
	choices: Array,
	accent_color: Color,
	show_ship_modules: bool = false,
) -> void:
	_apply_stage_rect()
	_set_input_enabled(false)
	_reset_result_state()
	_set_choices(choices)
	_focused_choice_index = 0
	_showing_ship_modules = show_ship_modules
	_set_ship_section_visible(show_ship_modules)
	_apply_header(title)
	_set_choice_buttons_visible(false)

	visible = true
	choice_container.visible = false
	backdrop.modulate.a = 0.0
	var backdrop_tween := _create_pause_tween()
	backdrop_tween.tween_property(backdrop, "modulate:a", 1.0, open_duration)
	await breakpoint_intro.play_intro(accent_color)

	choice_container.visible = true
	choice_container.modulate.a = 0.0
	_set_choice_buttons_visible(true)
	for index in current_choices.size():
		choice_buttons[index].position.y += ENTRANCE_DROP
	var open_tween := _create_pause_tween()
	open_tween.tween_property(choice_container, "modulate:a", 1.0, open_duration)
	_layout_choice_cards(true, open_duration + 0.1)
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
	_reset_result_state()
	choice_container.visible = true
	choice_container.modulate.a = 1.0
	breakpoint_intro.visible = false
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
	var target_modulate := _get_card_target_modulate(index)
	button.modulate = Color(target_modulate.r, target_modulate.g, target_modulate.b, 0.0)
	var tween := _create_pause_tween()
	tween.tween_property(button, "modulate", target_modulate, phase_transition_duration * 0.5).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_refresh_status_preview()


func set_reroll_state(remaining: int, enabled: bool) -> void:
	## Pass remaining < 0 to hide the reroll button (enemy offers).
	var show_reroll := remaining >= 0
	_reroll_enabled = show_reroll and enabled and remaining > 0
	reroll_button.visible = show_reroll
	reroll_button.disabled = not _reroll_enabled or not is_accepting_input
	if show_reroll:
		reroll_button.text = "[R] 리롤 (%d)" % maxi(0, remaining)
	_refresh_action_row()
	if is_accepting_input:
		_configure_focus_navigation()


func restore_for_result() -> void:
	_clear_status_preview()
	visible = true
	choice_container.visible = true
	choice_container.modulate.a = 1.0
	breakpoint_intro.visible = false
	_set_choice_buttons_visible(true)
	_set_input_enabled(false)


func hide_choices() -> void:
	suspend_choices()
	current_choices.clear()


func get_focused_choice_index() -> int:
	return _focused_choice_index


func _on_reroll_pressed() -> void:
	if not is_accepting_input or not _reroll_enabled:
		return
	reroll_requested.emit(_focused_choice_index)


func _apply_stage_rect() -> void:
	if stage == null:
		return
	if _stage_limit != null and is_instance_valid(_stage_limit) and _stage_limit.is_inside_tree():
		stage.anchor_right = 0.0
		stage.offset_right = _stage_limit.get_global_rect().position.x
	else:
		stage.anchor_right = 1.0
		stage.offset_right = 0.0


func _apply_header(title: String) -> void:
	title_label.text = title
	var tag_color := enemy_accent_color
	var tag_text := "THREAT"
	var first := current_choices[0] as PlayerAugment if not current_choices.is_empty() else null
	if first != null:
		tag_text = "%s TIER" % first.get_tier_label()
		tag_color = TIER_TAG_COLORS.get(first.tier, player_accent_color)
	tag_label.text = tag_text
	tag_label.add_theme_color_override(&"font_color", tag_color)
	if first != null:
		title_label.remove_theme_color_override(&"font_color")
	else:
		title_label.add_theme_color_override(&"font_color", ENEMY_TITLE_COLOR)
	accent_bar.color = tag_color


func _close_with_summary(result_title: String, result_text: String, _accent_color: Color) -> void:
	_set_input_enabled(false)
	_clear_status_preview()
	_showing_result = true
	var keep_index := _selected_index if _selected_index < current_choices.size() else -1
	if _layout_tween != null:
		_layout_tween.kill()

	var gather := _create_pause_tween().set_parallel(true)
	var duration := phase_transition_duration * 0.75
	gather.tween_property(action_row, "modulate:a", 0.0, duration)
	gather.tween_property(hint_label, "modulate:a", 0.0, duration)
	gather.tween_property(title_label, "modulate:a", 0.0, duration * 0.5)
	for index in current_choices.size():
		var button := choice_buttons[index]
		if index == keep_index:
			button.z_index = 1
			var center_x := (choice_row.size.x - CHOICE_CARD_SIZE.x) * 0.5
			gather.tween_property(button, "position", Vector2(center_x, CARD_TOP - FOCUS_LIFT), duration).set_trans(
				Tween.TRANS_CUBIC
			).set_ease(Tween.EASE_OUT)
			gather.tween_property(button, "scale", Vector2.ONE, duration)
			gather.tween_property(button, "modulate", FOCUSED_MODULATE, duration)
		else:
			gather.tween_property(button, "position:y", button.position.y + RESULT_DROP, duration)
			gather.tween_property(button, "modulate:a", 0.0, duration)
	await gather.finished

	title_label.text = result_title
	prompt_label.text = result_text
	# 남은 카드가 결과를 보여 주므로 문구는 고른 카드가 없을 때만 쓴다.
	prompt_label.visible = keep_index < 0
	prompt_label.modulate.a = 0.0
	if keep_index < 0:
		# 고른 카드가 없으면 문구를 카드 자리 가운데에 둔다.
		prompt_label.offset_top = choice_row.offset_top + choice_row.size.y * 0.5 - 13.0
		prompt_label.offset_bottom = prompt_label.offset_top + 26.0
	var reveal := _create_pause_tween().set_parallel(true)
	reveal.tween_property(title_label, "modulate:a", 1.0, phase_transition_duration * 0.5)
	reveal.tween_property(prompt_label, "modulate:a", 1.0, phase_transition_duration * 0.5)
	await reveal.finished
	await _wait(result_hold_duration)

	var close_tween := _create_pause_tween()
	close_tween.tween_property(stage, "modulate:a", 0.0, close_duration)
	await close_tween.finished
	visible = false
	current_choices.clear()
	_reset_result_state()


func _reset_result_state() -> void:
	_showing_result = false
	_selected_index = -1
	stage.modulate.a = 1.0
	action_row.modulate.a = 1.0
	hint_label.modulate.a = 1.0
	title_label.modulate.a = 1.0
	prompt_label.visible = false
	prompt_label.modulate.a = 1.0
	prompt_label.offset_top = 290.0
	prompt_label.offset_bottom = 316.0


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
	var scene: PackedScene = ENEMY_CARD_SCENE
	if player_augment != null:
		scene = CARD_SCENES[int(player_augment.tier)]
	var art := button.get_node_or_null("CardArt")
	if art != null and art.scene_file_path != scene.resource_path:
		button.remove_child(art)
		art.queue_free()
		art = null
	if art == null:
		art = scene.instantiate()
		art.name = "CardArt"
		button.add_child(art)
		button.move_child(art, 0)
	art.visible = true
	if player_augment != null:
		art.configure(player_augment, _weapon_loadout)
		button.set_meta("player_augment_tier", player_augment.tier)
	else:
		var enemy_icon := augment.get("icon") as Texture2D
		art.configure_copy(
			str(augment.get("display_name")),
			str(augment.get("description")),
			enemy_icon if enemy_icon != null else ENEMY_FALLBACK_ICON,
		)
		button.set_meta("player_augment_tier", -1)
	button.text = ""
	button.icon = null


func _set_ship_section_visible(section_visible: bool) -> void:
	if not section_visible:
		_clear_status_preview()
	slot_action_label.visible = section_visible
	_refresh_action_row()


## 하단 행은 리롤이나 슬롯 확장 중 하나라도 있을 때만 보이고, 안내 문구도 그에 맞춘다.
func _refresh_action_row() -> void:
	action_row.visible = reroll_button.visible or slot_action_label.visible
	var actions := PackedStringArray()
	if reroll_button.visible:
		actions.append("리롤")
	if slot_action_label.visible:
		actions.append("슬롯")
	hint_label.text = CARD_HINT
	if not actions.is_empty():
		hint_label.text += " · ↓ %s" % "/".join(actions)


func _highlight_choice(index: int) -> void:
	if index < 0 or index >= current_choices.size() or _showing_result:
		return
	var focus_changed := _focused_choice_index != index
	_focused_choice_index = index
	_layout_choice_cards(focus_changed and visible)
	_refresh_status_preview()


func _refresh_status_preview() -> void:
	if not _showing_ship_modules or _focused_choice_index < 0 or _focused_choice_index >= current_choices.size():
		_clear_status_preview()
		if is_accepting_input:
			_configure_focus_navigation()
		return
	var augment := current_choices[_focused_choice_index] as PlayerAugment
	if augment == null:
		_clear_status_preview()
		return
	slot_action_label.visible = true
	_refresh_slot_expansion_action()
	if PlayerAugmentKind.is_weapon_offer(augment.augment_type):
		if _status_ship_panel != null:
			_status_ship_panel.set_highlighted_facility(&"")
			_status_ship_panel.set_augment_preview(null)
		if _status_weapon_hud != null:
			_status_weapon_hud.show_augment_preview(augment)
	elif PlayerAugmentKind.is_facility_offer(augment.augment_type):
		if _status_weapon_hud != null:
			_status_weapon_hud.clear_augment_preview()
		if _status_ship_panel != null:
			_status_ship_panel.set_highlighted_facility(augment.get_primary_module_tag())
			_status_ship_panel.set_augment_preview(augment)
	else:
		# Rule cards take no slot or bay, so nothing blinks.
		if _status_weapon_hud != null:
			_status_weapon_hud.clear_augment_preview()
		if _status_ship_panel != null:
			_status_ship_panel.set_highlighted_facility(&"")
			_status_ship_panel.set_augment_preview(null)
	_refresh_expansion_preview()
	if is_accepting_input:
		_configure_focus_navigation()


func _refresh_slot_expansion_action() -> void:
	var capacity := _player_registry.get_slot_capacity() if _player_registry != null else 0
	var can_expand := _player_registry != null and _player_registry.can_expand_slots()
	if can_expand:
		slot_action_label.text = "스킵 · 범용 슬롯 +1 (%d→%d)" % [capacity, capacity + 1]
	else:
		slot_action_label.text = "범용 슬롯 MAX"
	slot_action_label.disabled = not is_accepting_input or not can_expand


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
		_highlight_choice(index)
	_selected_index = index
	_set_input_enabled(false)
	choice_selected.emit(current_choices[index] as Resource)


func _on_expand_slot_pressed() -> void:
	if not is_accepting_input or not _showing_ship_modules:
		return
	if _status_ship_panel != null:
		_status_ship_panel.set_expansion_preview(false)
	_selected_index = -1
	_set_input_enabled(false)
	universal_slot_expansion_selected.emit()


func _on_control_hovered(control: Control) -> void:
	if not is_accepting_input or not visible:
		return
	var button := control as BaseButton
	if button != null and button.disabled:
		return
	control.grab_focus()


func _set_choice_buttons_visible(buttons_visible: bool) -> void:
	for index in choice_buttons.size():
		choice_buttons[index].visible = buttons_visible and index < current_choices.size()
	_layout_choice_cards(false)


func _set_input_enabled(enabled: bool) -> void:
	is_accepting_input = enabled
	for button in choice_buttons:
		button.disabled = not enabled
	if _showing_ship_modules:
		_refresh_slot_expansion_action()
	else:
		slot_action_label.disabled = true
	_refresh_expansion_preview()
	reroll_button.disabled = not enabled or not _reroll_enabled
	if enabled:
		_configure_focus_navigation()


func _refresh_expansion_preview() -> void:
	if _status_ship_panel == null:
		return
	var pointer_inside := (
		slot_action_label.is_visible_in_tree()
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
		if augment != null and PlayerAugmentKind.is_facility_offer(augment.augment_type):
			_status_ship_panel.set_augment_preview(augment)


func _queue_expansion_preview_refresh() -> void:
	_refresh_expansion_preview.call_deferred()


## 카드: 좌우 순환, 아래는 하단 행. 하단 행: 좌우 순환, 위는 포커스 카드.
## 무대 밖(HUD)으로 포커스가 새지 않도록 빈 방향은 자기 자신을 가리킨다.
func _configure_focus_navigation() -> void:
	var cards: Array[Control] = []
	for button in choice_buttons:
		if button.visible and not button.disabled:
			cards.append(button)
	var actions: Array[Control] = []
	for button: Button in [reroll_button, slot_action_label]:
		if button.is_visible_in_tree() and not button.disabled:
			actions.append(button)
	if cards.is_empty():
		return
	var focused_card: Control = choice_buttons[clampi(_focused_choice_index, 0, current_choices.size() - 1)]
	if not cards.has(focused_card):
		focused_card = cards[0]

	for index in cards.size():
		var card := cards[index]
		_set_focus_neighbor(card, "focus_neighbor_left", cards[(index - 1 + cards.size()) % cards.size()])
		_set_focus_neighbor(card, "focus_neighbor_right", cards[(index + 1) % cards.size()])
		_set_focus_neighbor(card, "focus_neighbor_top", card)
		_set_focus_neighbor(card, "focus_neighbor_bottom", actions[0] if not actions.is_empty() else card)
	for index in actions.size():
		var action := actions[index]
		_set_focus_neighbor(action, "focus_neighbor_left", actions[(index - 1 + actions.size()) % actions.size()])
		_set_focus_neighbor(action, "focus_neighbor_right", actions[(index + 1) % actions.size()])
		_set_focus_neighbor(action, "focus_neighbor_top", focused_card)
		_set_focus_neighbor(action, "focus_neighbor_bottom", action)

	var tab_ring: Array[Control] = []
	tab_ring.append_array(cards)
	tab_ring.append_array(actions)
	for index in tab_ring.size():
		_set_focus_neighbor(tab_ring[index], "focus_previous", tab_ring[(index - 1 + tab_ring.size()) % tab_ring.size()])
		_set_focus_neighbor(tab_ring[index], "focus_next", tab_ring[(index + 1) % tab_ring.size()])


func _set_focus_neighbor(control: Control, property_name: String, target: Control) -> void:
	if target == null:
		return
	control.set(property_name, control.get_path_to(target))


func _on_choice_row_resized() -> void:
	if not _showing_result:
		_layout_choice_cards(false)


## 카드를 무대 가운데에 가로로 정렬하고 포커스 카드를 띄운다.
func _layout_choice_cards(animated: bool = true, duration: float = -1.0) -> void:
	if choice_row == null or _showing_result:
		return
	if _layout_tween != null:
		_layout_tween.kill()
		_layout_tween = null
	var count := current_choices.size()
	if count == 0:
		return
	var total_width := CHOICE_CARD_SIZE.x * count + CARD_GAP * (count - 1)
	var start_x := floorf((choice_row.size.x - total_width) * 0.5)
	if animated:
		_layout_tween = _create_pause_tween().set_parallel(true)
	var tween_duration := focus_transition_duration if duration < 0.0 else duration
	for index in count:
		var button := choice_buttons[index]
		var focused := index == _focused_choice_index
		var target_position := Vector2(
			start_x + index * (CHOICE_CARD_SIZE.x + CARD_GAP),
			CARD_TOP - (FOCUS_LIFT if focused else 0.0),
		)
		var target_scale := Vector2.ONE if focused else UNFOCUSED_SCALE
		var target_modulate := FOCUSED_MODULATE if focused else UNFOCUSED_MODULATE
		button.z_index = 1 if focused else 0
		if animated:
			_layout_tween.tween_property(button, "position", target_position, tween_duration).set_trans(
				Tween.TRANS_QUAD
			).set_ease(Tween.EASE_OUT)
			_layout_tween.tween_property(button, "scale", target_scale, tween_duration).set_trans(
				Tween.TRANS_QUAD
			).set_ease(Tween.EASE_OUT)
			_layout_tween.tween_property(button, "modulate", target_modulate, tween_duration)
		else:
			button.position = target_position
			button.scale = target_scale
			button.modulate = target_modulate


func _get_card_target_modulate(index: int) -> Color:
	return FOCUSED_MODULATE if index == _focused_choice_index else UNFOCUSED_MODULATE


func _get_focused_player_augment() -> PlayerAugment:
	if _focused_choice_index < 0 or _focused_choice_index >= current_choices.size():
		return null
	return current_choices[_focused_choice_index] as PlayerAugment


func _wait(duration: float) -> void:
	if duration <= 0.0:
		return
	var tween := _create_pause_tween()
	tween.tween_interval(duration)
	await tween.finished


func _create_pause_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _unhandled_input(event: InputEvent) -> void:
	if not is_accepting_input or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _reroll_enabled and (key.keycode == KEY_R or key.physical_keycode == KEY_R):
			_on_reroll_pressed()
			get_viewport().set_input_as_handled()
