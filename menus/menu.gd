extends Control

## 시작화면. 규칙: docs/design/scene-flow.md (Menu)

const GAME_SCENE_PATH := "res://world.tscn"
const FADE_IN_DURATION := 0.4
const FADE_OUT_DURATION := 0.2
const TITLE_PULSE_SPEED := 1.6
const TITLE_PULSE_AMOUNT := 0.08

@export var game_stats: GameStats

@onready var content: Control = $Margin
@onready var title_label: Label = %TitleLabel
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var status_label: Label = %StatusLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var fade: ColorRect = %Fade

var _game_scene: PackedScene
var _start_requested := false
var _transition_started := false
var _load_failed := false
var _buttons: Array[Button] = []
var _default_focus: Button
var _elapsed := 0.0


func _ready() -> void:
	quit_button.visible = not OS.has_feature("web")
	for button: Button in [start_button, settings_button, quit_button]:
		if button.visible:
			_buttons.append(button)
			button.mouse_entered.connect(_on_button_hovered.bind(button))
	_link_focus_loop()
	start_button.pressed.connect(_request_start)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(get_tree().quit)
	settings_menu.closed.connect(_on_settings_closed)

	high_score_label.text = "최고 점수 %06d" % (game_stats.highscore if game_stats != null else 0)
	status_label.text = ""
	_default_focus = start_button
	start_button.grab_focus()
	_fade_in()

	var error := ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	if error != OK:
		push_error("Failed to begin loading the game scene: %s" % error_string(error))
		_set_load_failed()


func _process(delta: float) -> void:
	_elapsed += delta
	var pulse := 1.0 + sin(_elapsed * TITLE_PULSE_SPEED) * TITLE_PULSE_AMOUNT
	title_label.self_modulate = Color(pulse, pulse, pulse, 1.0)
	_poll_game_scene_load()
	if _start_requested:
		_enter_game_when_ready()


func _unhandled_input(event: InputEvent) -> void:
	if settings_menu.visible or _start_requested:
		return
	if UiFocus.needs_focus_restore(get_viewport(), event):
		_restore_focus()
		accept_event()


func _request_start() -> void:
	if _start_requested or _load_failed:
		return
	_start_requested = true
	for button in _buttons:
		if button != start_button:
			_set_button_enabled(button, false)
	status_label.text = "게임 준비 중..."


func _poll_game_scene_load() -> void:
	if _game_scene != null or _load_failed:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _start_requested and not progress.is_empty():
				status_label.text = "게임 준비 중... %d%%" % roundi(progress[0] * 100.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			_game_scene = ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to load the game scene.")
			_set_load_failed()


func _enter_game_when_ready() -> void:
	if _game_scene == null or _transition_started:
		return
	_transition_started = true
	status_label.text = "게임 시작 중..."
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE_OUT_DURATION)
	await tween.finished
	_swap_to_game_scene()


## Builds World behind the black fade and swaps scenes by hand. With
## change_scene_to_packed the menu is freed first, so the viewport shows an
## empty clear-colour (grey) frame for as long as world.tscn takes to
## instantiate (~300 ms). Adding World before freeing the menu keeps the
## screen black until the first World frame is ready.
func _swap_to_game_scene() -> void:
	var tree := get_tree()
	var world := _game_scene.instantiate()
	tree.root.add_child(world)
	tree.current_scene = world
	queue_free()


func _set_load_failed() -> void:
	_load_failed = true
	_start_requested = false
	status_label.text = "게임 로딩 실패"
	for button in _buttons:
		_set_button_enabled(button, button != start_button)
	_default_focus = settings_button
	if start_button.has_focus() or get_viewport().gui_get_focus_owner() == null:
		settings_button.grab_focus()
	_link_focus_loop()


func _open_settings() -> void:
	if _start_requested:
		return
	_default_focus = settings_button
	for button in _buttons:
		button.focus_mode = Control.FOCUS_NONE
	content.visible = false
	settings_menu.open()


func _on_settings_closed() -> void:
	content.visible = true
	for button in _buttons:
		if not button.disabled:
			button.focus_mode = Control.FOCUS_ALL
	settings_button.grab_focus()


func _set_button_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _on_button_hovered(button: Button) -> void:
	if not settings_menu.visible and not button.disabled:
		button.grab_focus()


func _restore_focus() -> void:
	if _default_focus != null and not _default_focus.disabled:
		_default_focus.grab_focus()


## 활성 항목끼리 위/아래 순환 포커스를 연결한다.
func _link_focus_loop() -> void:
	UiFocus.link_vertical_loop(_buttons.filter(func(button: Button) -> bool: return not button.disabled))


func _fade_in() -> void:
	fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, FADE_IN_DURATION)
