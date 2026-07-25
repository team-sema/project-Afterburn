class_name AugmentSelectionOverlay
extends CanvasLayer

signal choice_selected(choice: Resource)

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
@onready var choice_buttons: Array[Button] = [
	%ChoiceButton1,
	%ChoiceButton2,
	%ChoiceButton3,
]

var current_choices: Array = []
var is_accepting_input := false


func _ready() -> void:
	for index in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
	visible = false


func open_choices(title: String, prompt: String, choices: Array, accent_color: Color) -> void:
	_set_input_enabled(false)
	_set_choices(choices)
	accent_bar.color = accent_color
	_set_choice_buttons_visible(false)

	visible = true
	choice_container.visible = false
	backdrop.modulate.a = 0.0
	var backdrop_tween := _create_pause_tween()
	backdrop_tween.tween_property(backdrop, "modulate:a", 1.0, open_duration)
	await breakpoint_intro.play_intro()

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
	open_tween.tween_property(panel_container, "scale", Vector2.ONE, open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await open_tween.finished
	_set_input_enabled(true)
	choice_buttons[0].grab_focus()


func transition_choices(title: String, prompt: String, choices: Array, accent_color: Color) -> void:
	_set_input_enabled(false)
	await _fade_content(0.0, phase_transition_duration)
	_set_choices(choices)
	title_label.text = title
	prompt_label.text = prompt
	accent_bar.color = accent_color
	_set_choice_buttons_visible(true)
	await _fade_content(1.0, phase_transition_duration)
	_set_input_enabled(true)
	choice_buttons[0].grab_focus()


func close_with_result(player_augment: PlayerAugment, enemy_augment: EnemyAugment) -> void:
	_set_input_enabled(false)
	await _fade_content(0.0, phase_transition_duration * 0.75)
	current_choices.clear()
	_set_choice_buttons_visible(false)
	title_label.text = "강화 확정"
	prompt_label.text = "아군: %s\n위협: %s" % [player_augment.display_name, enemy_augment.display_name]
	accent_bar.color = Color.WHITE
	await _fade_content(1.0, phase_transition_duration)
	await _wait(result_hold_duration)

	var close_tween := _create_pause_tween().set_parallel(true)
	close_tween.tween_property(backdrop, "modulate:a", 0.0, close_duration)
	close_tween.tween_property(panel_container, "modulate:a", 0.0, close_duration)
	close_tween.tween_property(panel_container, "scale", Vector2(0.97, 0.97), close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
		button.text = "%s\n%s" % [augment.get("display_name"), augment.get("description")]
		button.visible = true


func hide_choices() -> void:
	_set_input_enabled(false)
	breakpoint_intro.visible = false
	visible = false
	current_choices.clear()


func _on_choice_pressed(index: int) -> void:
	if not is_accepting_input:
		return
	if index < 0 or index >= current_choices.size():
		return
	_set_input_enabled(false)
	choice_selected.emit(current_choices[index] as Resource)


func _set_choice_buttons_visible(buttons_visible: bool) -> void:
	for index in choice_buttons.size():
		choice_buttons[index].visible = buttons_visible and index < current_choices.size()


func _set_input_enabled(enabled: bool) -> void:
	is_accepting_input = enabled
	for button in choice_buttons:
		button.disabled = not enabled


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
