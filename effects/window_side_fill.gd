extends Control
## Decorative space outside the fixed cockpit; never receives gameplay input.
const FILL_SHADER := preload("res://effects/window_side_fill.gdshader")
var background: SpaceBackground
var elapsed := 0.0
var sides: Array[ColorRect] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in 2:
		var rect := ColorRect.new()
		rect.name = "Left" if side == 0 else "Right"
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = FILL_SHADER
		shader_material.set_shader_parameter("right_side", side == 1)
		rect.material = shader_material
		add_child(rect)
		sides.append(rect)

func fit_to_window(window_size: Vector2) -> void:
	var margin := maxf(0.0, (window_size.x - CockpitGeometry.SHELL_SIZE.x) * 0.5)
	visible = margin > 0.0
	set_process(visible)
	for side in sides.size():
		var rect := sides[side]
		rect.position = Vector2.ZERO if side == 0 else Vector2(window_size.x - margin, 0)
		rect.size = Vector2(margin, window_size.y)
		(rect.material as ShaderMaterial).set_shader_parameter("extent", rect.size)

func _process(delta: float) -> void:
	if is_instance_valid(background):
		elapsed += delta * background.speed_scale
	for rect in sides:
		(rect.material as ShaderMaterial).set_shader_parameter("elapsed", elapsed)
