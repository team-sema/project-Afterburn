class_name SpaceBackground
extends ParallaxBackground

## Three-layer parallax star field (docs/design/effects.md 「World」).
## Cruise speeds are multiplied by `speed_scale`; above STREAK_THRESHOLD a
## layer of cyan-white streak lines fades in so a burst reads as speed.

## space / far stars / close stars, px/s at speed_scale 1.
const CRUISE_SPEEDS := Vector3(12.0, 40.0, 160.0)
const STREAK_THRESHOLD := 2.0
const STREAK_COUNT := 24
const STREAK_MAX_LENGTH := 80.0
const STREAK_COLOR := Color(0.75, 0.95, 1.0)

@export_range(0.0, 20.0, 0.01) var speed_scale := 1.0

@onready var space_layer: ParallaxLayer = %SpaceLayer
@onready var far_stars_layer: ParallaxLayer = %FarStarsLayer
@onready var close_stars_layer: ParallaxLayer = %CloseStarsLayer
@onready var space: TextureRect = $SpaceLayer/Space
@onready var far_stars: TextureRect = $FarStarsLayer/FarStars
@onready var close_stars: TextureRect = $CloseStarsLayer/CloseStars

var _streak_layer: StreakLayer


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
	_update_streaks(delta)


## px/s of a layer right now (0 = space, 1 = far stars, 2 = close stars).
func get_layer_speed(layer_index: int) -> float:
	return CRUISE_SPEEDS[layer_index] * speed_scale


func is_streaking() -> bool:
	return _streak_layer != null and _streak_layer.alpha > 0.0


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
	for texture_rect in [space, far_stars, close_stars]:
		texture_rect.position = Vector2.ZERO
		texture_rect.size = viewport_size
	for parallax_layer in [space_layer, far_stars_layer, close_stars_layer]:
		parallax_layer.motion_mirroring.y = viewport_size.y
