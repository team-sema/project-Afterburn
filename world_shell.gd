extends Control

const MASTER_VOLUME_CONTROL_SCENE := preload("res://menus/master_volume_control.tscn")
const MENU_SCENE_PATH := "res://menus/menu.tscn"

@onready var gameplay: Node = $Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay
@onready var pause_overlay: PauseMenu = %PauseOverlay
@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var status_ship_panel: ShipPanel = $Layout/RightPanel/Margin/VBox/ShipPanel
@onready var left_panel_content: VBoxContainer = $Layout/LeftPanel/Margin/VBox
@onready var weapon_loadout_hud: WeaponLoadoutHud = (
	$Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud
)

var _is_manual_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_master_volume_control()
	pause_overlay.resume_requested.connect(_set_manual_pause.bind(false))
	pause_overlay.settings_requested.connect(_open_settings)
	pause_overlay.main_menu_requested.connect(_return_to_menu)
	settings_menu.closed.connect(_on_settings_closed)
	var overlays: Array[CanvasLayer] = []
	for overlay_name in [
		"AugmentSelectionOverlay",
		"WeaponSlotSelectionOverlay",
		"AugmentModuleSwapOverlay",
	]:
		var overlay := gameplay.get_node(overlay_name) as CanvasLayer
		assert(overlay != null, "World shell requires %s." % overlay_name)
		overlays.append(overlay)
	for overlay in overlays:
		overlay.reparent(self)
	var augment_selection := get_node("AugmentSelectionOverlay") as AugmentSelectionOverlay
	assert(augment_selection != null, "World shell requires the augment selection overlay.")
	augment_selection.configure_status_preview(status_ship_panel, weapon_loadout_hud)
	augment_selection.configure_stage_limit($Layout/RightPanel)


func _add_master_volume_control() -> void:
	if left_panel_content.has_node("MasterVolumeControl"):
		return
	left_panel_content.add_child(MASTER_VOLUME_CONTROL_SCENE.instantiate())


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ESCAPE and key_event.physical_keycode != KEY_ESCAPE:
		return
	if get_tree().paused and not _is_manual_pause:
		return
	if settings_menu.visible:
		return

	_set_manual_pause(not _is_manual_pause)
	get_viewport().set_input_as_handled()


func _set_manual_pause(paused: bool) -> void:
	_is_manual_pause = paused
	if paused:
		pause_overlay.open()
	else:
		pause_overlay.close()
	get_tree().paused = paused


func _open_settings() -> void:
	pause_overlay.set_suspended(true)
	settings_menu.open()


func _on_settings_closed() -> void:
	pause_overlay.set_suspended(false)
	pause_overlay.focus_settings_item()


func _return_to_menu() -> void:
	_is_manual_pause = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _exit_tree() -> void:
	if _is_manual_pause and get_tree() != null:
		get_tree().paused = false
