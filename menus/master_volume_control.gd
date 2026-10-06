class_name MasterVolumeControl
extends HBoxContainer

const MASTER_BUS := &"Master"

@onready var volume_slider: HSlider = %VolumeSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	volume_slider.set_value_no_signal(GameSettings.instance.get_volume(MASTER_BUS))
	volume_slider.value_changed.connect(_on_slider_changed)
	GameSettings.instance.volume_changed.connect(_on_settings_volume_changed)


func _on_slider_changed(value: float) -> void:
	GameSettings.instance.set_volume(MASTER_BUS, value)


func _on_settings_volume_changed(bus: StringName, value: float) -> void:
	if bus == MASTER_BUS:
		volume_slider.set_value_no_signal(value)
