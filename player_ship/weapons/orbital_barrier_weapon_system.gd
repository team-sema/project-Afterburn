class_name OrbitalBarrierWeaponSystem
extends WeaponSystem

@export var orbit_radius := 22.0
@export var base_orbit_speed := 2.8
@export var base_damage := 6
@export var segment_max_health := 1
## Capsule half-width (thickness of the shield arc).
@export var segment_thickness := 5.0
## Capsule length along the orbit (covers most of a 120° sector).
@export var segment_arc_length := 34.0

@onready var orbit_root: Node2D = $OrbitRoot

var _alive_segments: Array[Node2D] = []
var _segment_max_count := 0


func _ready() -> void:
	_layout_segments()
	_wire_segments()
	_apply_stat_multipliers()


func _process(delta: float) -> void:
	if is_shutdown or _player == null or not is_instance_valid(_player):
		return
	global_position = (_player as Node2D).global_position
	var speed := base_orbit_speed * get_effective_fire_rate_multiplier()
	orbit_root.rotation += speed * delta


func _on_weapon_setup() -> void:
	set_process(true)
	_apply_stat_multipliers()


func _on_weapon_shutdown() -> void:
	set_process(false)
	for segment in _alive_segments.duplicate():
		_disable_segment_collision(segment)


func get_consumable_remaining() -> int:
	# Segments are visible in-world; HUD does not need a charge fraction.
	return -1


func get_consumable_max() -> int:
	return -1


func _on_refill_consumable() -> void:
	_restore_all_segments()


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var damage_mult := get_effective_damage_multiplier()
	for child in orbit_root.get_children():
		var hitbox := child.get_node_or_null("HitboxComponent") as HitboxComponent
		if hitbox == null:
			continue
		hitbox.damage = maxi(1, roundi(base_damage * damage_mult))


func _layout_segments() -> void:
	var segments := orbit_root.get_children()
	var count := segments.size()
	if count == 0:
		return
	for index in count:
		var segment := segments[index] as Node2D
		if segment == null:
			continue
		var angle := TAU * float(index) / float(count)
		segment.position = Vector2(cos(angle), sin(angle)) * orbit_radius
		# Capsule is vertical by default; rotate so its length follows the orbit tangent.
		segment.rotation = angle + PI * 0.5
		_apply_segment_shapes(segment)
		var glow := segment.get_node_or_null("Glow") as Sprite2D
		if glow != null:
			glow.scale = Vector2(0.08, 0.22)
		var core := segment.get_node_or_null("Core") as Sprite2D
		if core != null:
			core.scale = Vector2(0.035, 0.12)


func _apply_segment_shapes(segment: Node2D) -> void:
	var capsule := CapsuleShape2D.new()
	capsule.radius = segment_thickness
	capsule.height = maxf(segment_thickness * 2.0, segment_arc_length)
	for area_name in ["HitboxComponent", "HurtboxComponent"]:
		var area := segment.get_node_or_null(area_name) as Area2D
		if area == null:
			continue
		var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null:
			continue
		shape_node.shape = capsule


func _wire_segments() -> void:
	_alive_segments.clear()
	_segment_max_count = 0
	for child in orbit_root.get_children():
		var segment := child as Node2D
		if segment == null:
			continue
		var stats := segment.get_node_or_null("StatsComponent") as StatsComponent
		if stats == null:
			push_error("OrbitalBarrier segment missing StatsComponent.")
			continue
		_segment_max_count += 1
		stats.health = segment_max_health
		if not stats.no_health.is_connected(_on_segment_no_health.bind(segment)):
			stats.no_health.connect(_on_segment_no_health.bind(segment))
		_set_segment_visuals(segment, true)
		_enable_segment_collision(segment)
		_alive_segments.append(segment)


func _restore_all_segments() -> void:
	_alive_segments.clear()
	for child in orbit_root.get_children():
		var segment := child as Node2D
		if segment == null:
			continue
		var stats := segment.get_node_or_null("StatsComponent") as StatsComponent
		if stats == null:
			continue
		stats.health = segment_max_health
		_set_segment_visuals(segment, true)
		_enable_segment_collision(segment)
		_alive_segments.append(segment)


func _on_segment_no_health(segment: Node2D) -> void:
	if segment == null or not is_instance_valid(segment) or is_shutdown:
		return
	_alive_segments.erase(segment)
	_disable_segment_collision(segment)
	_set_segment_visuals(segment, false)
	# Segments may die in combat; the weapon stays equipped (no ammo / no auto-unequip).


func _set_segment_visuals(segment: Node2D, active: bool) -> void:
	for child in segment.get_children():
		if child is CanvasItem and not (child is Area2D):
			(child as CanvasItem).visible = active
	segment.modulate = Color.WHITE


func _disable_segment_collision(segment: Node2D) -> void:
	var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox != null:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	var hurtbox := segment.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		hurtbox.is_invincible = true


func _enable_segment_collision(segment: Node2D) -> void:
	var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox != null:
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
	var hurtbox := segment.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", true)
		hurtbox.is_invincible = false
