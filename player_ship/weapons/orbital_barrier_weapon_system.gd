class_name OrbitalBarrierWeaponSystem
extends WeaponSystem

@export var orbit_radius := 22.0
@export var base_orbit_speed := 2.8
@export var base_damage := 6
## Capsule half-width (thickness of the shield arc).
@export var segment_thickness := 5.0
## Capsule length along the orbit (covers most of a 120° sector).
@export var segment_arc_length := 34.0

@onready var orbit_root: Node2D = $OrbitRoot

var _segments: Array[Node2D] = []


func get_status_stat_line() -> String:
	return "접촉피해 %d · 반경 %s · 회전 %s" % [
		_status_damage(base_damage),
		_status_num(orbit_radius, 0),
		_status_num(base_orbit_speed * get_effective_fire_rate_multiplier()),
	]


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
	for segment in _segments:
		_enable_segment_collision(segment)


func _on_weapon_shutdown() -> void:
	set_process(false)
	for segment in _segments:
		_disable_segment_collision(segment)


func get_consumable_remaining() -> int:
	# No ammo / no segment HP; HUD does not need a charge fraction.
	return -1


func get_consumable_max() -> int:
	return -1


func _on_refill_consumable() -> void:
	pass


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var damage_mult := get_effective_damage_multiplier()
	for segment in _segments:
		var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
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
	_segments.clear()
	for child in orbit_root.get_children():
		var segment := child as Node2D
		if segment == null:
			continue
		var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
		var hurtbox := segment.get_node_or_null("HurtboxComponent") as HurtboxComponent
		if hitbox == null or hurtbox == null:
			push_error("OrbitalBarrier segment missing HitboxComponent/HurtboxComponent.")
			continue
		# Hitbox damages enemies. Hurtbox has no HP — enemy bullets hit it and self-destroy.
		_enable_segment_collision(segment)
		_segments.append(segment)


func _disable_segment_collision(segment: Node2D) -> void:
	var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox != null:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	var hurtbox := segment.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		hurtbox.is_invincible = true
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)


func _enable_segment_collision(segment: Node2D) -> void:
	var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox != null:
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
	var hurtbox := segment.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		# Absorb enemy projectiles (they queue_free on hit_hurtbox). No Stats/Hurt — no HP.
		hurtbox.is_invincible = false
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", true)
