class_name SpaceBackground
extends ParallaxBackground

## Parallax star field (docs/design/effects.md 「World」).
## Layer order: Space (black + dots) → Nebula (BackdropTheme colour field) →
## Rocks (BackdropTheme silhouettes) → far stars → close stars → orbital ring → speed streaks.
## Cruise speeds are multiplied by `speed_scale`; above STREAK_THRESHOLD a
## layer of cyan-white streak lines fades in so a burst reads as speed.

## space / far stars / close stars, px/s at speed_scale 1.
const CRUISE_SPEEDS := Vector3(12.0, 40.0, 160.0)
const STREAK_THRESHOLD := 2.0
const STREAK_COUNT := 24
const STREAK_MAX_LENGTH := 80.0
const STREAK_COLOR := Color(0.75, 0.95, 1.0)
const ROCK_VERTEX_COUNT := 7
const PLANET_RING_SEGMENTS := 40
const PLANET_RING_TILT := -0.35
const ORBITAL_RING_SHADER := preload("res://effects/orbital_ring.gdshader")

@export_range(0.0, 20.0, 0.01) var speed_scale := 1.0
## Horizontal px drawn beyond each side of the visible rect (lane). Layers keep
## their lane-relative placement; only their rects extend into the bleed.
@export_range(0.0, 320.0, 1.0) var bleed := 0.0:
	set(value):
		bleed = value
		if is_node_ready():
			_apply_bleed()
## 성운·실루엣·행성·궤도 링 데이터. null이면 별밭만 그린다.
@export var backdrop: BackdropTheme:
	set(value):
		backdrop = value
		if is_node_ready():
			_build_backdrop()

@onready var space_layer: ParallaxLayer = %SpaceLayer
@onready var far_stars_layer: ParallaxLayer = %FarStarsLayer
@onready var close_stars_layer: ParallaxLayer = %CloseStarsLayer
@onready var space: TextureRect = $SpaceLayer/Space
@onready var far_stars: TextureRect = $FarStarsLayer/FarStars
@onready var close_stars: TextureRect = $CloseStarsLayer/CloseStars

var _streak_layer: StreakLayer
var _nebula_layer: ParallaxLayer
var _rock_layer: ParallaxLayer
var _orbital_ring: ColorRect
var _base_tint: ColorRect
var _orbital_elapsed := 0.0
var _built_size := Vector2.ZERO


class StreakLayer:
	extends Node2D
	var streaks: Array[Vector3] = []  # x, y, speed factor
	var length := 0.0
	var alpha := 0.0

	func _draw() -> void:
		if alpha <= 0.0 or length <= 0.0:
			return
		var color := Color(STREAK_COLOR.r, STREAK_COLOR.g, STREAK_COLOR.b, alpha)
		for streak in streaks:
			var head := Vector2(streak.x, streak.y)
			draw_line(head - Vector2(0.0, length * streak.z), head, color, 1.0)


func _ready() -> void:
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)
	_streak_layer = StreakLayer.new()
	_streak_layer.name = "SpeedStreaks"
	_streak_layer.z_index = 1
	add_child(_streak_layer)
	_seed_streaks()


func _process(delta: float) -> void:
	space_layer.motion_offset.y += CRUISE_SPEEDS.x * speed_scale * delta
	far_stars_layer.motion_offset.y += CRUISE_SPEEDS.y * speed_scale * delta
	close_stars_layer.motion_offset.y += CRUISE_SPEEDS.z * speed_scale * delta
	if backdrop != null:
		if _nebula_layer != null:
			_nebula_layer.motion_offset.y += backdrop.nebula_speed * speed_scale * delta
		if _rock_layer != null:
			_rock_layer.motion_offset.y += backdrop.rock_speed * speed_scale * delta
		if _orbital_ring != null:
			_orbital_elapsed += delta * speed_scale
			(_orbital_ring.material as ShaderMaterial).set_shader_parameter("elapsed", _orbital_elapsed)
	_update_streaks(delta)


## px/s of a layer right now (0 = space, 1 = far stars, 2 = close stars).
func get_layer_speed(layer_index: int) -> float:
	return CRUISE_SPEEDS[layer_index] * speed_scale


func is_streaking() -> bool:
	return _streak_layer != null and _streak_layer.alpha > 0.0


func get_nebula_layer() -> ParallaxLayer:
	return _nebula_layer


func get_rock_layer() -> ParallaxLayer:
	return _rock_layer


func get_orbital_ring() -> ColorRect:
	return _orbital_ring


func _seed_streaks() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_streak_layer.streaks.clear()
	for _index in STREAK_COUNT:
		_streak_layer.streaks.append(Vector3(
			randf_range(0.0, viewport_size.x),
			randf_range(0.0, viewport_size.y),
			randf_range(0.7, 1.4),
		))


func _update_streaks(delta: float) -> void:
	if _streak_layer == null:
		return
	var excess := speed_scale - STREAK_THRESHOLD
	var was_visible := _streak_layer.alpha > 0.0
	_streak_layer.alpha = clampf(excess / 4.0, 0.0, 0.8)
	_streak_layer.length = clampf(excess * 14.0, 0.0, STREAK_MAX_LENGTH)
	if _streak_layer.alpha <= 0.0:
		if was_visible:
			_streak_layer.queue_redraw()
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var speed := CRUISE_SPEEDS.z * speed_scale * delta
	for index in _streak_layer.streaks.size():
		var streak := _streak_layer.streaks[index]
		streak.y += speed * streak.z
		if streak.y - _streak_layer.length * streak.z > viewport_size.y:
			streak.y = -randf_range(0.0, viewport_size.y * 0.5)
			streak.x = randf_range(0.0, viewport_size.x)
		_streak_layer.streaks[index] = streak
	_streak_layer.queue_redraw()


func _resize_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for parallax_layer in [space_layer, far_stars_layer, close_stars_layer]:
		parallax_layer.motion_mirroring.y = viewport_size.y
	# The render target may grow or shrink (bleed) without changing the lane;
	# only a lane change rebuilds the theme layers, so scroll offsets survive.
	if viewport_size == _built_size:
		_apply_bleed()
		return
	_built_size = viewport_size
	_apply_bleed()
	_build_backdrop()


## Stretches the full-width rects sideways by `bleed` without rebuilding.
func _apply_bleed() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var rect_position := Vector2(-bleed, 0.0)
	var rect_size := viewport_size + Vector2(bleed * 2.0, 0.0)
	for rect in [space, far_stars, close_stars, _base_tint, _orbital_ring]:
		if rect == null:
			continue
		rect.position = rect_position
		rect.size = rect_size
	if _orbital_ring != null:
		var ring_material := _orbital_ring.material as ShaderMaterial
		ring_material.set_shader_parameter("rect_size", rect_size)
		ring_material.set_shader_parameter("rect_offset", rect_position)


## Rebuilds theme layers for the current viewport. Nebula and rocks tile vertically;
## the orbital landmark spans the screen without repeating.
func _build_backdrop() -> void:
	if _orbital_ring != null:
		_orbital_ring.free()
		_orbital_ring = null
	if _nebula_layer != null:
		_nebula_layer.free()
		_nebula_layer = null
		_base_tint = null
	if _rock_layer != null:
		_rock_layer.free()
		_rock_layer = null
	if backdrop == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	_nebula_layer = ParallaxLayer.new()
	_nebula_layer.name = "NebulaLayer"
	_nebula_layer.motion_mirroring.y = viewport_size.y
	var base := ColorRect.new()
	base.name = "BaseTint"
	base.color = backdrop.base_tint
	base.position = Vector2(-bleed, 0.0)
	base.size = viewport_size + Vector2(bleed * 2.0, 0.0)
	_nebula_layer.add_child(base)
	_base_tint = base
	for index in backdrop.nebula_count():
		var disc := _make_soft_disc(backdrop.nebula_colors[index], backdrop.nebula_radii[index])
		disc.name = "Nebula%d" % index
		disc.position = backdrop.nebula_positions[index] * viewport_size
		_nebula_layer.add_child(disc)
	add_child(_nebula_layer)
	move_child(_nebula_layer, space_layer.get_index() + 1)

	_rock_layer = ParallaxLayer.new()
	_rock_layer.name = "RockLayer"
	_rock_layer.motion_mirroring.y = viewport_size.y
	for index in backdrop.rock_count():
		var rock := _make_rock(backdrop.rock_sizes[index], index)
		rock.name = "Rock%d" % index
		rock.position = backdrop.rock_positions[index] * viewport_size
		_rock_layer.add_child(rock)
	if backdrop.planet_radius > 0.0:
		var planet := _make_soft_disc(backdrop.planet_color, backdrop.planet_radius)
		planet.name = "Planet"
		planet.position = backdrop.planet_position * viewport_size
		var ring := Line2D.new()
		ring.name = "Ring"
		ring.width = 1.2
		ring.default_color = backdrop.planet_ring_color
		for index in PLANET_RING_SEGMENTS + 1:
			var angle := TAU * index / float(PLANET_RING_SEGMENTS)
			var point := Vector2(cos(angle) * backdrop.planet_radius * 1.45, sin(angle) * backdrop.planet_radius * 0.35)
			ring.add_point(point.rotated(PLANET_RING_TILT))
		planet.add_child(ring)
		_rock_layer.add_child(planet)
	add_child(_rock_layer)
	move_child(_rock_layer, _nebula_layer.get_index() + 1)
	if backdrop.orbital_ring_enabled:
		_orbital_ring = ColorRect.new()
		_orbital_ring.name = "OrbitalRing"
		_orbital_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_orbital_ring.position = Vector2(-bleed, 0.0)
		_orbital_ring.size = viewport_size + Vector2(bleed * 2.0, 0.0)
		var ring_material := ShaderMaterial.new()
		ring_material.shader = ORBITAL_RING_SHADER
		ring_material.set_shader_parameter("viewport_size", viewport_size)
		ring_material.set_shader_parameter("rect_size", _orbital_ring.size)
		ring_material.set_shader_parameter("rect_offset", _orbital_ring.position)
		ring_material.set_shader_parameter("elapsed", _orbital_elapsed)
		_orbital_ring.material = ring_material
		add_child(_orbital_ring)
		move_child(_orbital_ring, close_stars_layer.get_index() + 1)


## A sprite whose radial gradient fades from `color` to transparent at `radius`.
static func _make_soft_disc(color: Color, radius: float) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = maxi(2, int(radius * 2.0))
	texture.height = texture.width
	var sprite := Sprite2D.new()
	sprite.texture = texture
	return sprite


## An irregular dark polygon; `seed_index` keeps each rock's shape stable across rebuilds.
func _make_rock(size: float, seed_index: int) -> Polygon2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_index * 7919 + 17
	var points := PackedVector2Array()
	for index in ROCK_VERTEX_COUNT:
		var angle := TAU * index / float(ROCK_VERTEX_COUNT) + rng.randf_range(-0.2, 0.2)
		var radius := size * rng.randf_range(0.7, 1.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = backdrop.rock_color
	return polygon
