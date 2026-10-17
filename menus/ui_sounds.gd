class_name UiSounds
extends Node

## Autoload (UiSoundHub): UI sound effects on the SFX bus, playing through pause.
## Every BaseButton press plays `accept` unless the button sets the meta
## PRESS_META to another id (or &"" for silence). Focus moves play `focus` (or
## the control's FOCUS_META id) only when a direction/Tab key or the mouse
## caused them, so screens grabbing focus on open stay quiet.
## Rules: docs/design/scene-flow.md「UI 효과음」.

const PRESS_META := &"ui_press_sound"
const FOCUS_META := &"ui_focus_sound"
const VOICES := 4
## id -> [stream, volume_db]
const SOUNDS := {
	&"focus": [preload("res://sounds/ui/ui_focus.ogg"), -10.0],
	&"accept": [preload("res://sounds/ui/ui_accept.ogg"), -6.0],
	&"back": [preload("res://sounds/ui/ui_back.ogg"), -6.0],
	&"augment_ready": [preload("res://sounds/ui/augment_ready.ogg"), -6.0],
	&"augment_offer_open": [preload("res://sounds/ui/augment_offer_open.ogg"), -4.0],
	&"augment_card_focus": [preload("res://sounds/ui/augment_card_focus.ogg"), -8.0],
	&"augment_card_select": [preload("res://sounds/ui/augment_card_select.ogg"), -4.0],
}
const NAV_ACTIONS := [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

static var instance: UiSounds

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_nav_frame := -100
var _last_pointer_frame := -100
## Last id played and when, for tests and to drop same-frame duplicates.
var last_played := &""
var _last_played_frame := -1


## Plays `id` if the autoload is running (no-op in bare script tests).
static func play(id: StringName) -> void:
	if instance != null and is_instance_valid(instance):
		instance.play_sound(id)


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	get_tree().node_added.connect(_on_node_added)
	_watch_viewport(get_viewport())


func play_sound(id: StringName) -> void:
	if id == &"" or not SOUNDS.has(id):
		return
	var frame := int(Engine.get_process_frames())
	if id == last_played and frame == _last_played_frame:
		return
	last_played = id
	_last_played_frame = frame
	var entry: Array = SOUNDS[id]
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = entry[0]
	voice.volume_db = entry[1]
	if voice.is_inside_tree():
		voice.play()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_pointer_frame = int(Engine.get_process_frames())
		return
	for action in NAV_ACTIONS:
		if event.is_action_pressed(action, true):
			_last_nav_frame = int(Engine.get_process_frames())
			return


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed.bind(button))
	elif node is Viewport:
		_watch_viewport(node as Viewport)


func _watch_viewport(viewport: Viewport) -> void:
	if viewport != null and not viewport.gui_focus_changed.is_connected(_on_focus_changed):
		viewport.gui_focus_changed.connect(_on_focus_changed)


func _on_button_pressed(button: BaseButton) -> void:
	play_sound(button.get_meta(PRESS_META, &"accept"))


func _on_focus_changed(control: Control) -> void:
	var frame := int(Engine.get_process_frames())
	if frame - _last_nav_frame > 1 and frame - _last_pointer_frame > 1:
		return
	play_sound(control.get_meta(FOCUS_META, &"focus"))
