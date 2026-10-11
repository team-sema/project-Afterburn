class_name PlayfieldDamageWarning
extends Node2D

## Red gradient hugging the inside of the playfield while the shield is empty.
## Flashes on the hit that broke the shield, then pulses in step with the
## cockpit lamps until the shield comes back. Rules: docs/design/player.md.

const NODE_NAME := "PlayfieldDamageWarning"
const GAMEPLAY_WORLD_GROUP := "gameplay_world"
const EDGE_WIDTH := 36.0
const COLOR := Color(0.95, 0.2, 0.22)
const FLASH_ALPHA := 0.3
const FLASH_DURATION := 0.5
const PULSE_PERIOD := 0.8
const PULSE_MIN := 0.04
const PULSE_MAX := 0.1
const FADE_OUT := 0.3
## Behind every z=0 world item (bullets, ship) and above the parallax background.
const Z_INDEX := -1

var _active := false
var _flash_left := 0.0
var _pulse_elapsed := 0.0
var _fade_left := 0.0
var _alpha := 0.0


static func get_or_create(source: Node) -> PlayfieldDamageWarning:
	var tree := source.get_tree()
	if tree == null:
		return null
	var host := tree.get_first_node_in_group(GAMEPLAY_WORLD_GROUP)
	if host == null:
		host = tree.current_scene
	if host == null:
		return null
	var existing := host.get_node_or_null(NodePath(NODE_NAME)) as PlayfieldDamageWarning
	if existing != null:
		return existing
	var warning := PlayfieldDamageWarning.new()
	warning.name = NODE_NAME
	host.add_child(warning)
	return warning


func _ready() -> void:
	z_index = Z_INDEX
	set_process(false)
	queue_redraw()


## Shield just hit zero. `flash` is false for a run that starts without shield.
func start(flash: bool = true) -> void:
	_active = true
	_fade_left = 0.0
	_flash_left = FLASH_DURATION if flash else 0.0
	_pulse_elapsed = 0.0
	set_process(true)
	_update_alpha()


## Shield recovered: fade out over FADE_OUT seconds.
func stop() -> void:
	if not _active:
		return
	_active = false
	_flash_left = 0.0
	_fade_left = FADE_OUT if _alpha > 0.0 else 0.0
	set_process(_fade_left > 0.0)
	_update_alpha()


func is_active() -> bool:
	return _active


func get_alpha() -> float:
	return _alpha


func _process(delta: float) -> void:
	if _active:
		if _flash_left > 0.0:
			_flash_left = maxf(0.0, _flash_left - delta)
		else:
			_pulse_elapsed = fmod(_pulse_elapsed + delta, PULSE_PERIOD)
	elif _fade_left > 0.0:
		_fade_left = maxf(0.0, _fade_left - delta)
		if _fade_left <= 0.0:
			set_process(false)
	_update_alpha()


func _update_alpha() -> void:
	var next := 0.0
	if _active:
		var pulse := lerpf(PULSE_MIN, PULSE_MAX, 0.5 + 0.5 * cos(TAU * _pulse_elapsed / PULSE_PERIOD))
		if _flash_left > 0.0:
			# Flash settles onto the pulse's upper bound, which the pulse then takes over.
			next = lerpf(PULSE_MAX, FLASH_ALPHA, _flash_left / FLASH_DURATION)
		else:
			next = pulse
	elif _fade_left > 0.0:
		next = _alpha * (_fade_left / FADE_OUT)
	if is_equal_approx(next, _alpha):
		return
	_alpha = next
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	# Cover everything the viewport renders, not just the 340px logical lane:
	# the cockpit field bleeds 16px past the lane on each side, and a band that
	# stops at the lane edge reads as a floating rectangle inside the frame.
	var viewport := get_viewport()
	var rect := get_viewport_transform().affine_inverse() * Rect2(Vector2.ZERO, Vector2(viewport.size))
	var outer := Color(COLOR, _alpha)
	var inner := Color(COLOR, 0.0)
	var w := minf(EDGE_WIDTH, minf(rect.size.x, rect.size.y) * 0.5)
	var l := rect.position.x
	var t := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	# Four trapezoids whose outer edge is opaque and inner edge transparent.
	_draw_band([Vector2(l, t), Vector2(r, t), Vector2(r - w, t + w), Vector2(l + w, t + w)], outer, inner)
	_draw_band([Vector2(r, b), Vector2(l, b), Vector2(l + w, b - w), Vector2(r - w, b - w)], outer, inner)
	_draw_band([Vector2(l, b), Vector2(l, t), Vector2(l + w, t + w), Vector2(l + w, b - w)], outer, inner)
	_draw_band([Vector2(r, t), Vector2(r, b), Vector2(r - w, b - w), Vector2(r - w, t + w)], outer, inner)


func _draw_band(points: Array, outer: Color, inner: Color) -> void:
	draw_polygon(PackedVector2Array(points), PackedColorArray([outer, outer, inner, inner]))
