extends Node2D

## Elite Bomb mine: eases from the thrower to a landing point, shows its blast
## radius while flashing, then hurts the player inside it and fires a ring.

signal detonated(mine: Node2D)

const PLAYER_HURTBOX_MASK := 1 << 0
const EXPLOSION = preload("res://effects/explosion_effect.tscn")
const BODY_COLOR := Color(1.0, 0.22, 0.32, 1.0)
const CORE_COLOR := Color(1.0, 0.92, 0.94, 1.0)
const FILL_COLOR := Color(1.0, 0.12, 0.08, 0.07)
const OUTLINE_COLOR := Color(1.0, 0.22, 0.14, 0.24)
const FLASH_FILL_COLOR := Color(1.0, 0.12, 0.08, 0.2)
const FLASH_OUTLINE_COLOR := Color(1.0, 0.25, 0.2, 0.75)
const BLAST_COLOR := Color(1.0, 0.12, 0.25, 1.0)

var start_position := Vector2.ZERO
var landing_position := Vector2.ZERO
var flight_duration := 0.6
var arm_duration := 1.5
var flash_count := 3
var blast_radius := 44.0
var blast_damage := 1
var ring_shot: BarrageShot
var ring_count := 10
var ring_speed := 80.0
var ring_angle_degrees := 0.0

var landed := false
var _elapsed := 0.0


func _ready() -> void:
	global_position = start_position


func _process(delta: float) -> void:
	_elapsed += delta
	if not landed:
		var t := clampf(_elapsed / maxf(0.001, flight_duration), 0.0, 1.0)
		global_position = start_position.lerp(landing_position, 1.0 - (1.0 - t) * (1.0 - t))
		if t < 1.0:
			queue_redraw()
			return
		landed = true
		_elapsed -= flight_duration
	if _elapsed >= arm_duration:
		detonate()
		return
	queue_redraw()


func is_flashing() -> bool:
	if not landed:
		return false
	var period := arm_duration / float(maxi(1, flash_count))
	return fmod(_elapsed, period) < period * 0.55


func detonate() -> void:
	if is_queued_for_deletion():
		return
	var parent := get_parent() as Node2D
	if parent != null:
		var effect := EXPLOSION.instantiate() as Node2D
		parent.add_child(effect)
		effect.global_position = global_position
		effect.call("set_effect_radius", blast_radius)
		effect.call("set_effect_color", BLAST_COLOR)
		_fire_ring(parent)
	_hurt_player()
	detonated.emit(self)
	queue_free()


func _fire_ring(parent: Node2D) -> void:
	if ring_shot == null:
		return
	for index in ring_count:
		var angle := deg_to_rad(ring_angle_degrees + 360.0 * index / ring_count)
		ring_shot.spawn(parent, global_position, Vector2.DOWN.rotated(angle), ring_speed)


func _hurt_player() -> void:
	var world := get_world_2d()
	if world == null:
		return
	var circle := CircleShape2D.new()
	circle.radius = blast_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = PLAYER_HURTBOX_MASK
	var hitbox := HitboxComponent.new()
	hitbox.damage = blast_damage
	for result in world.direct_space_state.intersect_shape(params, 32):
		var hurtbox := result.get("collider") as HurtboxComponent
		if hurtbox != null and not hurtbox.is_invincible:
			hurtbox.hurt.emit(hitbox)
	hitbox.free()


func _draw() -> void:
	if landed:
		var flashing := is_flashing()
		draw_circle(Vector2.ZERO, blast_radius, FLASH_FILL_COLOR if flashing else FILL_COLOR)
		draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 96, FLASH_OUTLINE_COLOR if flashing else OUTLINE_COLOR, 1.0, true)
	var body := PackedVector2Array()
	for index in 8:
		body.append(Vector2.from_angle(TAU * (index + 0.5) / 8.0) * 5.0)
	draw_colored_polygon(body, BODY_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -2.5), Vector2(2.5, 0), Vector2(0, 2.5), Vector2(-2.5, 0)]), CORE_COLOR)
