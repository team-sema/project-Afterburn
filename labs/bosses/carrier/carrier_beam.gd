extends Node2D
## Continuous carrier hazard (engine exhaust, bridge laser) pointing along local +Y.
## Charge shows a harmless guide line; only the firing state enables the hitbox.
var length := 420.0
var visual_width := 22.0
var hit_width := 10.0
var glow_color := Color(1.0, 0.35, 0.1)
var hot_color := Color(1.0, 0.9, 0.7)
var charge_time := 0.0
var charge_left := 0.0
var fire_left := 0.0
var clock := 0.0
var firing := false
var hitbox: HitboxComponent
var shape: CollisionShape2D
var body: Sprite2D
var material_beam: ShaderMaterial

func _ready() -> void:
	add_to_group("carrier_hazards")
	body = Sprite2D.new()
	# Solid 1x1 quad: the shader draws the whole beam from UVs.
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	body.texture = ImageTexture.create_from_image(image)
	body.centered = false
	body.offset = Vector2(-0.5, 0)
	body.scale = Vector2(visual_width, length)
	material_beam = ShaderMaterial.new()
	material_beam.shader = preload("res://effects/laser_beam.gdshader")
	material_beam.set_shader_parameter("glow_color", glow_color)
	material_beam.set_shader_parameter("hot_color", hot_color)
	material_beam.set_shader_parameter("beam_length", length)
	material_beam.set_shader_parameter("tight_radius", 0.22)
	material_beam.set_shader_parameter("tight_strength", 0.9)
	material_beam.set_shader_parameter("wide_strength", 0.25)
	body.material = material_beam
	body.visible = false
	add_child(body)
	hitbox = HitboxComponent.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(hit_width, length)
	shape.shape = rectangle
	shape.position.y = length * 0.5
	shape.disabled = true
	hitbox.add_child(shape)
	add_child(hitbox)

func charge(seconds: float) -> void:
	charge_time = seconds
	charge_left = seconds
	fire_left = 0
	_set_firing(false)

func fire(seconds: float) -> void:
	charge_left = 0
	fire_left = seconds
	_set_firing(true)

func stop() -> void:
	charge_left = 0
	fire_left = 0
	_set_firing(false)

func is_busy() -> bool:
	return charge_left > 0 or fire_left > 0

func _set_firing(value: bool) -> void:
	firing = value
	if shape != null: shape.set_deferred("disabled", not value)
	if body != null: body.visible = value
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock += delta
	if charge_left > 0:
		charge_left = maxf(0, charge_left - delta)
	elif fire_left > 0:
		fire_left -= delta
		if fire_left <= 0: _set_firing(false)
	if firing:
		# Short ignition and cut-off keep the width change readable at 60 fps.
		var envelope := clampf(minf(fire_left, 0.12) / 0.12, 0.0, 1.0)
		body.scale.x = visual_width * lerpf(0.35, 1.0, envelope)
		material_beam.set_shader_parameter("beam_time", clock)
	queue_redraw()

func _draw() -> void:
	if charge_left <= 0: return
	var progress := 1.0 - charge_left / maxf(charge_time, 0.01)
	var pulse := 0.55 + 0.45 * sin(clock * 30.0)
	var color := Color(glow_color, (0.18 + progress * 0.45) * pulse)
	draw_line(Vector2.ZERO, Vector2(0, length), color, 0.6 + progress * 1.6, true)
	for side in [-1, 1]:
		# Edge ticks shrink toward the final lane so the danger width is legible.
		var edge: float = side * lerpf(visual_width, hit_width * 0.5, progress)
		draw_line(Vector2(edge, 0), Vector2(edge, length), Color(glow_color, 0.12 * progress), 1.0)
