extends Control

## 게임 오버. 규칙: docs/design/scene-flow.md (Game Over)

const MENU_SCENE := preload("uid://bjwoypvha1bvg")
const FADE_IN_DURATION := 0.4
const FADE_OUT_DURATION := 0.2

@export var game_stats: GameStats

@onready var score_value: Label = %ScoreValue
@onready var high_score_value: Label = %HighScoreValue
@onready var record_label: Label = %RecordLabel
@onready var menu_button: Button = %MenuButton
@onready var fade: ColorRect = %Fade

var _leaving := false


func _ready() -> void:
	var new_record := game_stats.score > game_stats.highscore
	if new_record:
		game_stats.highscore = game_stats.score
	score_value.text = "%06d" % game_stats.score
	high_score_value.text = "%06d" % game_stats.highscore
	record_label.visible = new_record

	menu_button.pressed.connect(_return_to_menu)
	menu_button.mouse_entered.connect(menu_button.grab_focus)
	UiFocus.link_vertical_loop([menu_button])
	menu_button.grab_focus()
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, FADE_IN_DURATION)


func _unhandled_input(event: InputEvent) -> void:
	if not _leaving and UiFocus.needs_focus_restore(get_viewport(), event):
		menu_button.grab_focus()
		accept_event()


func _return_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE_OUT_DURATION)
	await tween.finished
	get_tree().change_scene_to_packed(MENU_SCENE)
