class_name OrbitalBarrierWeaponSystem
extends WeaponSystem

@export var orbit_radius := 18.0
@export var base_orbit_speed := 2.8
@export var base_damage := 6
@export var segment_max_health := 2
@export_range(0.1, 60.0, 0.1) var segment_regeneration_time := 3.0
@export_range(0.0, 1.0, 0.05) var depleted_alpha := 0.2

@onready var orbit_root: Node2D = $OrbitRoot

var _base_damages: Array[int] = []
var _alive_segments: Array[Node2D] = []


func _ready() -> void:
	_cache_base_damages()
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


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var damage_mult := get_effective_damage_multiplier()
	var index := 0
	for child in orbit_root.get_children():
		var hitbox := child.get_node_or_null("HitboxComponent") as HitboxComponent
		if hitbox == null:
			continue
		var base := base_damage
		if index < _base_damages.size():
			base = _base_damages[index]
		hitbox.damage = maxi(1, roundi(base * damage_mult))
		index += 1


func _cache_base_damages() -> void:
	_base_damages.clear()
	for child in orbit_root.get_children():
		var hitbox := child.get_node_or_null("HitboxComponent") as HitboxComponent
		if hitbox != null:
			_base_damages.append(hitbox.damage)


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


func _wire_segments() -> void:
	_alive_segments.clear()
	for child in orbit_root.get_children():
		var segment := child as Node2D
		if segment == null:
			continue
		var stats := segment.get_node_or_null("StatsComponent") as StatsComponent
		if stats == null:
			push_error("OrbitalBarrier segment missing StatsComponent.")
			continue
		stats.health = segment_max_health
		if not stats.no_health.is_connected(_on_segment_no_health.bind(segment)):
			stats.no_health.connect(_on_segment_no_health.bind(segment))
		_alive_segments.append(segment)


func _on_segment_no_health(segment: Node2D) -> void:
	if segment == null or not is_instance_valid(segment):
		return
	_alive_segments.erase(segment)
	_disable_segment_collision(segment)
	segment.modulate.a = depleted_alpha
	_regenerate_segment(segment)


func _regenerate_segment(segment: Node2D) -> void:
	await get_tree().create_timer(segment_regeneration_time, false).timeout
	if is_shutdown or segment == null or not is_instance_valid(segment):
		return
	var stats := segment.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		push_error("OrbitalBarrier segment missing StatsComponent during regeneration.")
		return
	stats.health = segment_max_health
	segment.modulate.a = 1.0
	_enable_segment_collision(segment)
	if not _alive_segments.has(segment):
		_alive_segments.append(segment)


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
