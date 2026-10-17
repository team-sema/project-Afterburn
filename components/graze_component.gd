class_name GrazeComponent
extends Area2D

## Player graze: while any enemy bullet sits inside a ring around the hit point
## (hit point radius + MARGIN), every GRAZE_INTERVAL of game time counts one
## graze, which charges the shield and adds score. FoundationBullets are
## reported by EnemyBulletPool (report_bullet); legacy bullets are found by
## this Area2D on the enemy_projectile layer. Lasers, beams and enemy bodies do
## not graze. Rules and numbers: docs/design/player.md「그레이즈」.

signal grazed(position: Vector2, charged: bool)

const GROUP := &"graze_receivers"
## Graze ring = hit point radius + this, so it follows the compressed core.
const MARGIN := 10.0
const GRAZE_INTERVAL := 0.1
const CHARGE_PER_GRAZE := 1.0 / 30.0
const SCORE_PER_GRAZE := 10
const INTERVAL_EPSILON := 0.000001

@export var hit_point: PlayerHitPoint
@export var shield_component: ShieldComponent
@export var game_stats: GameStats
@export var impact_profile: ImpactProfile = preload("res://effects/impact_profiles/player_graze.tres")

## Game seconds spent in range toward the next graze. Kept when the ring
## empties so short brushes add up.
var _accumulated := 0.0
var _graze_count := 0
var _reported_frame := -1
var _reported_point := Vector2.ZERO
var _reported_distance := INF
var _shape := CircleShape2D.new()
var _hurtbox: HurtboxComponent
var _hurt_shape: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	# Run after every EnemyBulletPool so this tick's reports are in.
	process_physics_priority = 10
	collision_layer = 0
	collision_mask = EnemyBullets.LAYER
	monitorable = false
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	add_child(collision)
	if hit_point != null:
		_hurtbox = hit_point.get_node_or_null("HurtboxComponent") as HurtboxComponent
		if _hurtbox != null:
			_hurt_shape = _hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_sync_ring()


func get_graze_count() -> int:
	return _graze_count


## Graze ring centre in global space (the hit point's hurtbox shape).
func get_center() -> Vector2:
	if _hurt_shape != null and _hurt_shape.is_inside_tree():
		return _hurt_shape.global_position
	if hit_point != null and hit_point.is_inside_tree():
		return hit_point.global_position
	return global_position


func get_radius() -> float:
	var base := hit_point.radius if hit_point != null else PlayerHitPoint.BASE_RADIUS
	return base + MARGIN


## Off while iframes (or any invincibility hold) are up or the ship is leaving.
func can_graze() -> bool:
	if not is_inside_tree():
		return false
	return _hurtbox == null or not _hurtbox.is_invincible


## EnemyBulletPool calls this for a bullet inside the ring this physics tick.
## Several pools may report; only the nearest point is kept for the spark.
func report_bullet(frame: int, point: Vector2) -> void:
	var distance := point.distance_squared_to(get_center())
	if frame != _reported_frame:
		_reported_frame = frame
		_reported_distance = INF
	if distance < _reported_distance:
		_reported_distance = distance
		_reported_point = point


func _physics_process(delta: float) -> void:
	_sync_ring()
	var frame := int(Engine.get_physics_frames())
	var in_range := _reported_frame == frame
	var nearest := _reported_point
	var nearest_distance := _reported_distance if in_range else INF
	var center := get_center()
	for area in get_overlapping_areas():
		if not area.is_inside_tree():
			continue
		var distance := area.global_position.distance_squared_to(center)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = area.global_position
			in_range = true
	if not in_range or not can_graze():
		return
	_accumulated += delta
	while _accumulated >= GRAZE_INTERVAL - INTERVAL_EPSILON:
		_accumulated = maxf(0.0, _accumulated - GRAZE_INTERVAL)
		_graze_once(nearest)


func _graze_once(bullet_point: Vector2) -> void:
	_graze_count += 1
	var charged := shield_component != null and shield_component.add_graze_charge(CHARGE_PER_GRAZE)
	if game_stats != null:
		game_stats.score += SCORE_PER_GRAZE
	var center := get_center()
	var direction := (bullet_point - center).normalized() if bullet_point.distance_squared_to(center) > 0.0001 else Vector2.UP
	var spark_position := center + direction * get_radius()
	if impact_profile != null:
		ImpactVfx.emit_from(self, spark_position, impact_profile, direction)
	grazed.emit(spark_position, charged)


func _sync_ring() -> void:
	var radius := get_radius()
	if not is_equal_approx(_shape.radius, radius):
		_shape.radius = radius
	if is_inside_tree():
		var center := get_center()
		if global_position != center:
			global_position = center
