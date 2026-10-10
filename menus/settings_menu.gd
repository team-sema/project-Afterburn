class_name SettingsMenu
extends Control

## 볼륨·창 모드 설정 모달. 규칙: docs/design/scene-flow.md (설정)

signal closed

const ROW_STYLE := &"SettingsRow"
const ROW_FOCUSED_STYLE := &"SettingsRowFocused"
const VOLUME_ROWS := {
	&"Master": ^"Center/Panel/VBox/Rows/MasterRow",
	&"Music": ^"Center/Panel/VBox/Rows/MusicRow",
	&"SFX": ^"Center/Panel/VBox/Rows/SfxRow",
}

@onready var fullscreen_row: PanelContainer = $Center/Panel/VBox/Rows/FullscreenRow
@onready var fullscreen_button: Button = %FullscreenButton
@onready var event_log_row: PanelContainer = $Center/Panel/VBox/Rows/EventLogRow
@onready var event_log_button: Button = %EventLogButton
@onready var back_button: Button = %BackButton

var _sliders := {}
var _value_labels := {}
## 위→아래 포커스 순서. 끝에서 반대쪽으로 순환한다.
var _focus_order: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for bus in VOLUME_ROWS:
		var row := get_node(VOLUME_ROWS[bus]) as PanelContainer
		var slider := row.get_node("HBox/Slider") as HSlider
		_sliders[bus] = slider
		_value_labels[bus] = row.get_node("HBox/Value") as Label
		slider.value_changed.connect(_on_slider_changed.bind(bus))
		_bind_row(row, slider)
		_focus_order.append(slider)
	_bind_row(fullscreen_row, fullscreen_button)
	_focus_order.append(fullscreen_button)
	_bind_row(event_log_row, event_log_button)
	_focus_order.append(event_log_button)
	_focus_order.append(back_button)
	back_button.mouse_entered.connect(back_button.grab_focus)
	UiFocus.link_vertical_loop(_focus_order)

	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	fullscreen_button.gui_input.connect(_on_fullscreen_gui_input)
	event_log_button.toggled.connect(GameSettings.instance.set_combat_event_log_enabled)
	event_log_button.gui_input.connect(_on_event_log_gui_input)
	GameSettings.instance.combat_event_log_changed.connect(_on_event_log_changed)
	back_button.pressed.connect(close)
	GameSettings.instance.volume_changed.connect(_on_settings_volume_changed)
	GameSettings.instance.fullscreen_changed.connect(_on_settings_fullscreen_changed)
	_sync_from_settings()


func open() -> void:
	_sync_from_settings()
	visible = true
	_focus_order[0].grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	GameSettings.instance.flush()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()
		return
	if UiFocus.needs_focus_restore(get_viewport(), event):
		_focus_order[0].grab_focus()
		accept_event()


func _bind_row(row: PanelContainer, control: Control) -> void:
	row.theme_type_variation = ROW_STYLE
	row.mouse_entered.connect(control.grab_focus)
	control.focus_entered.connect(func() -> void: row.theme_type_variation = ROW_FOCUSED_STYLE)
	control.focus_exited.connect(func() -> void: row.theme_type_variation = ROW_STYLE)


func _sync_from_settings() -> void:
	for bus in _sliders:
		var value := GameSettings.instance.get_volume(bus)
		(_sliders[bus] as HSlider).set_value_no_signal(value)
		_update_value_label(bus, value)
	fullscreen_button.set_pressed_no_signal(GameSettings.instance.is_fullscreen())
	_on_event_log_changed(GameSettings.instance.is_combat_event_log_enabled())
	_update_fullscreen_text()


func _on_slider_changed(value: float, bus: StringName) -> void:
	GameSettings.instance.set_volume(bus, value)
	_update_value_label(bus, value)


func _on_settings_volume_changed(bus: StringName, value: float) -> void:
	if not _sliders.has(bus):
		return
	(_sliders[bus] as HSlider).set_value_no_signal(value)
	_update_value_label(bus, value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	GameSettings.instance.set_fullscreen(enabled)
	_update_fullscreen_text()


## 좌/우로도 켬/끔을 바꾼다 (포커스 이동보다 먼저 처리).
func _on_fullscreen_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		fullscreen_button.button_pressed = not fullscreen_button.button_pressed
		fullscreen_button.accept_event()


func _on_settings_fullscreen_changed(enabled: bool) -> void:
	fullscreen_button.set_pressed_no_signal(enabled)
	_update_fullscreen_text()


func _update_value_label(bus: StringName, value: float) -> void:
	(_value_labels[bus] as Label).text = "%d%%" % roundi(value * 100.0)


func _update_fullscreen_text() -> void:
	fullscreen_button.text = "켬" if fullscreen_button.button_pressed else "끔"

func _on_event_log_changed(enabled: bool) -> void:
	event_log_button.set_pressed_no_signal(enabled)
	event_log_button.text = "켬" if enabled else "끔"

func _on_event_log_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		event_log_button.button_pressed = not event_log_button.button_pressed
		event_log_button.accept_event()
