extends CanvasLayer
## Render the actual game background independently of the Lab destruction camera.
const Playfield := preload("res://menus/playfield_layout.gd")
var background_viewport: SubViewport
var background: SpaceBackground

func _ready() -> void:
	layer = -100
	follow_viewport_enabled = false
	var container := SubViewportContainer.new()
	container.size = Vector2(Playfield.SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	background_viewport = SubViewport.new()
	background_viewport.size = Playfield.SIZE
	background_viewport.use_hdr_2d = true
	background_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(background_viewport)
	background = preload("res://effects/space_background.tscn").instantiate()
	background_viewport.add_child(background)
