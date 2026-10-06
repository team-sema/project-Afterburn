class_name GameSettings
extends Node

## 사용자 설정(볼륨·창 모드)을 읽고 적용·저장한다. 오토로드 `UserSettings`로 한 개만 띄우고
## 코드에서는 `GameSettings.instance`로 접근한다 (`--script` 테스트도 컴파일되도록 전역 이름을 쓰지 않음).
## 규칙: docs/design/scene-flow.md

signal volume_changed(bus: StringName, value: float)
signal fullscreen_changed(enabled: bool)

const SETTINGS_PATH := "user://settings.cfg"
const AUDIO_SECTION := "audio"
const DISPLAY_SECTION := "display"
const FULLSCREEN_KEY := "fullscreen"
const SAVE_DELAY := 0.25
const VOLUME_KEYS := {
	&"Master": "master_volume",
	&"Music": "music_volume",
	&"SFX": "sfx_volume",
}

static var instance: GameSettings

## 테스트는 false로 두어 사용자 설정 파일을 덮어쓰지 않는다.
var save_enabled := true

var _volumes := {}
var _fullscreen := false
var _save_timer: Timer
var _save_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)
	_load()
	for bus in VOLUME_KEYS:
		_apply_volume(bus)
	_apply_fullscreen()


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	flush()
	if instance == self:
		instance = null


func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, 1.0)


func set_volume(bus: StringName, value: float) -> void:
	if not VOLUME_KEYS.has(bus):
		push_error("Unknown settings audio bus: %s" % bus)
		return
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(get_volume(bus), value):
		return
	_volumes[bus] = value
	_apply_volume(bus)
	_queue_save()
	volume_changed.emit(bus, value)


func is_fullscreen() -> bool:
	return _fullscreen


func set_fullscreen(enabled: bool) -> void:
	if _fullscreen == enabled:
		return
	_fullscreen = enabled
	_apply_fullscreen()
	_queue_save()
	fullscreen_changed.emit(enabled)


## 대기 중인 변경을 즉시 저장한다.
func flush() -> void:
	if not _save_pending:
		return
	_save_pending = false
	if _save_timer != null:
		_save_timer.stop()
	if not save_enabled:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for bus in VOLUME_KEYS:
		config.set_value(AUDIO_SECTION, VOLUME_KEYS[bus], get_volume(bus))
	config.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, _fullscreen)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Failed to save settings: %s" % error_string(error))


func _load() -> void:
	var config := ConfigFile.new()
	var loaded := config.load(SETTINGS_PATH) == OK
	for bus in VOLUME_KEYS:
		var fallback := _current_bus_volume(bus)
		var value: Variant = fallback
		if loaded:
			value = config.get_value(AUDIO_SECTION, VOLUME_KEYS[bus], fallback)
		_volumes[bus] = clampf(float(value), 0.0, 1.0)
	_fullscreen = loaded and bool(config.get_value(DISPLAY_SECTION, FULLSCREEN_KEY, false))


func _current_bus_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0 if index >= 0 else 1.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


func _apply_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("Audio bus is missing: %s" % bus)
		return
	var value := get_volume(bus)
	var muted := is_zero_approx(value)
	AudioServer.set_bus_mute(index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(index, linear_to_db(value))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen_mode := (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if _fullscreen == is_fullscreen_mode:
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _queue_save() -> void:
	_save_pending = true
	if _save_timer != null and _save_timer.is_inside_tree():
		_save_timer.start()
