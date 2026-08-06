extends Control

@onready var gameplay: Node = $Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay
@onready var pause_overlay: ColorRect = %PauseOverlay
@onready var status_ship_panel: ShipPanel = $Layout/RightPanel/Margin/VBox/ShipPanel
@onready var weapon_loadout_hud: WeaponLoadoutHud = (
	$Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud
)

var _is_manual_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	_set_manual_pause(not _is_manual_pause)
	get_viewport().set_input_as_handled()


func _set_manual_pause(paused: bool) -> void:
	_is_manual_pause = paused
	pause_overlay.visible = paused
	get_tree().paused = paused


func _exit_tree() -> void:
	if _is_manual_pause and get_tree() != null:
		get_tree().paused = false
