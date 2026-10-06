class_name PauseMenu
extends ColorRect

## 전장 위 수동 일시정지 메뉴. 일시정지 소유권은 world_shell.gd가 관리한다.
## 규칙: docs/design/scene-flow.md (일시정지)

signal resume_requested
signal settings_requested
signal main_menu_requested

@onready var content: Control = $Center
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton

var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_buttons = [resume_button, settings_button, main_menu_button]
	for button in _buttons:
		button.mouse_entered.connect(_on_button_hovered.bind(button))
	UiFocus.link_vertical_loop(_buttons)
	resume_button.pressed.connect(resume_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	main_menu_button.pressed.connect(main_menu_requested.emit)


func open() -> void:
	set_suspended(false)
	visible = true
	resume_button.grab_focus()


func close() -> void:
	visible = false


## 설정 모달이 떠 있는 동안 항목을 숨기고 포커스 경로에서 뺀다. 어두운 바탕은 유지한다.
func set_suspended(suspended: bool) -> void:
	content.visible = not suspended
	for button in _buttons:
		button.focus_mode = Control.FOCUS_NONE if suspended else Control.FOCUS_ALL


func focus_settings_item() -> void:
	settings_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or resume_button.focus_mode == Control.FOCUS_NONE:
		return
	if UiFocus.needs_focus_restore(get_viewport(), event):
		resume_button.grab_focus()
		accept_event()


func _on_button_hovered(button: Button) -> void:
	if button.focus_mode != Control.FOCUS_NONE:
		button.grab_focus()
