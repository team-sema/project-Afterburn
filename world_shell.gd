extends Control

@onready var gameplay: Node = $Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay


func _ready() -> void:
	var overlays: Array[CanvasLayer] = []
	for overlay_name in [
		"AugmentSelectionOverlay",
		"WeaponSlotSelectionOverlay",
		"WeaponAcquireConfirmOverlay",
	]:
		var overlay := gameplay.get_node(overlay_name) as CanvasLayer
		assert(overlay != null, "World shell requires %s." % overlay_name)
		overlays.append(overlay)
	for overlay in overlays:
		overlay.reparent(self)
