extends Control

const COCKPIT_SCENE := preload("res://menus/cockpit_hud.gd")
## While the cockpit panels are still sliding in, the playfield renders the
## whole shell width so the uncovered sides show space instead of black.
const LAUNCH_BLEED := CockpitGeometry.FIELD_LEFT
const MENU_SCENE_PATH := "res://menus/menu.tscn"

@onready var playfield_viewport: SubViewport = $Layout/Playfield/ViewportContainer/PlayfieldViewport
@onready var gameplay: Node = $Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay
@onready var pause_overlay: PauseMenu = %PauseOverlay
@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var status_ship_panel: ShipPanel = $Layout/RightPanel/Margin/VBox/ShipPanel
@onready var left_panel_content: Control = $Layout/LeftPanel/Margin/VBox
@onready var weapon_loadout_hud: WeaponLoadoutHud = (
	$Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud
)

var _is_manual_pause := false
var _field_bleed := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backing := ColorRect.new()
	backing.color = Color(0.002, 0.005, 0.012)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backing)
	move_child(backing, 0)
	var cockpit := Control.new()
	cockpit.name = "CockpitHud"
	cockpit.set_script(COCKPIT_SCENE)
	$Layout.add_child(cockpit)
	cockpit.configure(self)
	var launch := gameplay.get_node("LaunchSequence") as LaunchSequence
	launch.launch_started.connect(_apply_field_bleed.bind(LAUNCH_BLEED))
	launch.launch_advanced.connect(_on_launch_advanced)
	_apply_field_bleed(LAUNCH_BLEED if launch.is_launching else CockpitGeometry.FIELD_BLEED)
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


## The lane stays 340x360 for gameplay logic (visible rect), but the viewport
## renders `bleed` px past each side: FIELD_BLEED once the cockpit is settled,
## so the aperture, which is wider than the lane around the console shoulders,
## never shows the lane edge; LAUNCH_BLEED while the panels deploy.
func _apply_field_bleed(bleed: float) -> void:
	if is_equal_approx(bleed, _field_bleed):
		return
	_field_bleed = bleed
	var container := playfield_viewport.get_parent() as SubViewportContainer
	container.offset_left = -bleed
	container.offset_right = bleed
	playfield_viewport.global_canvas_transform = Transform2D(0.0, Vector2(bleed, 0.0))
	var background := gameplay.get_node("SpaceBackground") as SpaceBackground
	background.bleed = bleed


func get_field_bleed() -> float:
	return _field_bleed


func _on_launch_advanced(time: float) -> void:
	if time >= COCKPIT_SCENE.DEPLOY_END:
		_apply_field_bleed(CockpitGeometry.FIELD_BLEED)


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
