class_name OrbitalBarrierWeaponSystem
extends WeaponSystem

@export var orbit_radius := 22.0
@export var base_orbit_speed := 2.8
@export var base_damage := 6
## Capsule half-width (thickness of the shield arc).
@export var segment_thickness := 5.0
## Capsule length along the orbit (covers most of a 120° sector). Base ~1/3 of prior 34.
@export var segment_arc_length := 11.33
@export_range(0.05, 5.0, 0.05) var base_rehit_cooldown := 1.0
@export_range(10.0, 400.0, 1.0) var knockback_strength := 140.0

const BASE_GLOW_SCALE := Vector2(0.08, 0.073)
const BASE_CORE_SCALE := Vector2(0.035, 0.04)

@onready var orbit_root: Node2D = $OrbitRoot

var _segments: Array[Node2D] = []
## Enemies already struck: id -> {node, until}  until<0 means forever (no rehit trait).
var _struck_targets: Dictionary = {}
var _template_segment: Node2D
var _base_segment_count := 0


func _ready() -> void:
	_capture_template()
	_layout_segments()
	_wire_segments()
	_apply_stat_multipliers()


func _process(delta: float) -> void:
	if is_shutdown or get_player_actor() == null or not is_instance_valid(get_player_actor()):
		return
	global_position = (get_player_actor() as Node2D).global_position
	var speed := base_orbit_speed * get_effective_fire_rate_multiplier()
	speed *= float(get_trait_param(&"barrier_fast_orbit", &"orbit_speed_mult", 1.0))
	speed *= float(get_trait_param(&"barrier_expand_axis", &"orbit_speed_mult", 1.0))
	orbit_root.rotation += speed * delta
	_prune_struck()


func _on_weapon_setup() -> void:
	connect_weapon_trait_changed(_on_weapon_trait_changed)
	set_process(true)
	_struck_targets.clear()
	_rebuild_segment_count()
	_apply_stat_multipliers()
	for segment in _segments:
		_enable_segment_collision(segment)


func _on_weapon_trait_changed(changed_weapon_id: StringName, _trait_id: StringName, _new_rank: int) -> void:
	if changed_weapon_id != get_weapon_id():
		return
	_rebuild_segment_count()
	_apply_stat_multipliers()


func _on_weapon_shutdown() -> void:
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	set_process(false)
	_struck_targets.clear()
	for segment in _segments:
		_disable_segment_collision(segment)


func get_consumable_remaining() -> int:
	return -1


func get_consumable_max() -> int:
	return -1


func _on_refill_consumable() -> void:
	pass


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var damage_mult := get_effective_damage_multiplier()
	damage_mult *= float(get_trait_param(&"barrier_multi", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"barrier_fast_orbit", &"damage_mult", 1.0))
	var radius := orbit_radius * float(get_trait_param(&"barrier_expand_axis", &"radius_mult", 1.0))
	var size_mult := float(get_trait_param(&"barrier_expand_axis", &"size_mult", 1.0))
	for segment in _segments:
		var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
		if hitbox != null:
			hitbox.damage = maxi(1, roundi(base_damage * damage_mult))
			hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
				return resolve_hit_damage(maxi(1, roundi(base_damage * float(get_trait_param(&"barrier_multi", &"damage_mult", 1.0)) * float(get_trait_param(&"barrier_fast_orbit", &"damage_mult", 1.0)))), hurtbox)
	_layout_segments_at(radius, size_mult)


func _capture_template() -> void:
	_segments.clear()
	for child in orbit_root.get_children():
		var segment := child as Node2D
		if segment == null:
			continue
		_segments.append(segment)
	_base_segment_count = _segments.size()
	if _base_segment_count > 0:
		_template_segment = _segments[0].duplicate() as Node2D


func _rebuild_segment_count() -> void:
	if _template_segment == null:
		_capture_template()
	var desired := _base_segment_count + int(get_trait_param(&"barrier_multi", &"count_bonus", 0))
	desired = maxi(1, desired)
	while _segments.size() < desired:
		var clone := _template_segment.duplicate() as Node2D
		orbit_root.add_child(clone)
		_segments.append(clone)
		_wire_one_segment(clone)
	while _segments.size() > desired:
		var extra := _segments.pop_back() as Node2D
		if is_instance_valid(extra) and extra != _template_segment:
			extra.queue_free()
	_layout_segments()
	_apply_stat_multipliers()


func _layout_segments() -> void:
	var radius := orbit_radius * float(get_trait_param(&"barrier_expand_axis", &"radius_mult", 1.0))
	var size_mult := float(get_trait_param(&"barrier_expand_axis", &"size_mult", 1.0))
	_layout_segments_at(radius, size_mult)


func _layout_segments_at(radius: float, size_mult: float) -> void:
	var count := _segments.size()
	if count == 0:
		return
	for index in count:
		var segment := _segments[index]
		if segment == null:
			continue
		var angle := TAU * float(index) / float(count)
		segment.position = Vector2(cos(angle), sin(angle)) * radius
		segment.rotation = angle + PI * 0.5
		_apply_segment_shapes(segment, size_mult)
		var glow := segment.get_node_or_null("Glow") as Sprite2D
		if glow != null:
			glow.scale = BASE_GLOW_SCALE * Vector2(1.0, size_mult)
		var core := segment.get_node_or_null("Core") as Sprite2D
		if core != null:
			core.scale = BASE_CORE_SCALE * Vector2(1.0, size_mult)


func _apply_segment_shapes(segment: Node2D, size_mult: float = 1.0) -> void:
	var capsule := CapsuleShape2D.new()
	capsule.radius = segment_thickness
	capsule.height = maxf(segment_thickness * 2.0, segment_arc_length * size_mult)
	for area_name in ["HitboxComponent", "HurtboxComponent"]:
		var area := segment.get_node_or_null(area_name) as Area2D
		if area == null:
			continue
		var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null:
			continue
		shape_node.shape = capsule


func _wire_segments() -> void:
	for segment in _segments:
		_wire_one_segment(segment)


func _wire_one_segment(segment: Node2D) -> void:
	var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
	var hurtbox := segment.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hitbox == null or hurtbox == null:
		push_error("OrbitalBarrier segment missing HitboxComponent/HurtboxComponent.")
		return
	var default_hit := Callable(hitbox, "_on_hurtbox_entered")
	if hitbox.area_entered.is_connected(default_hit):
		hitbox.area_entered.disconnect(default_hit)
	var bound := _on_barrier_hitbox_entered.bind(hitbox)
	if not hitbox.area_entered.is_connected(bound):
		hitbox.area_entered.connect(bound)
	_enable_segment_collision(segment)


func _uses_timed_rehit() -> bool:
	return has_trait(&"barrier_fast_orbit") or has_trait(&"barrier_repulse")


func _rehit_cooldown() -> float:
	var cd := base_rehit_cooldown
	cd *= float(get_trait_param(&"barrier_fast_orbit", &"rehit_cooldown_mult", 1.0))
	cd *= float(get_trait_param(&"barrier_repulse", &"rehit_cooldown_mult", 1.0))
	return maxf(0.05, cd)


func _on_barrier_hitbox_entered(hurtbox: Area2D, hitbox: HitboxComponent) -> void:
	if not hurtbox is HurtboxComponent:
		return
	var enemy_hurtbox := hurtbox as HurtboxComponent
	if enemy_hurtbox.is_invincible:
		return
	var target := _strike_target_from_hurtbox(enemy_hurtbox)
	if target == null:
		return
	if _has_struck(target):
		return
	_mark_struck(target)

	var damage_mult := float(get_trait_param(&"barrier_multi", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"barrier_fast_orbit", &"damage_mult", 1.0))
	var raw := maxi(1, roundi(base_damage * damage_mult))
	hitbox.damage = resolve_hit_damage(raw, enemy_hurtbox)
	hitbox.hit_hurtbox.emit(enemy_hurtbox)
	enemy_hurtbox.hurt.emit(hitbox)

	if has_trait(&"barrier_repulse"):
		_apply_repulse(target, enemy_hurtbox, raw)


func _apply_repulse(target: Node, hurtbox: HurtboxComponent, base_raw: int) -> void:
	var strength := float(get_trait_param(&"barrier_repulse", &"knockback_strength", knockback_strength))
	var shock_mult := float(get_trait_param(&"barrier_repulse", &"shock_damage_mult", 0.4))
	if target is Node2D and get_player_actor() is Node2D:
		var enemy := target as Node2D
		var away := enemy.global_position - (get_player_actor() as Node2D).global_position
		if away.length_squared() < 0.0001:
			away = Vector2.UP
		away = away.normalized()
		var modifier := enemy.get_node_or_null("MoveModifierComponent") as MoveModifierComponent
		if modifier != null:
			modifier.apply_impulse(away * strength)
	var shock := maxi(1, roundi(float(base_raw) * shock_mult))
	var shock_hitbox := HitboxComponent.new()
	shock_hitbox.damage = resolve_hit_damage(shock, hurtbox)
	hurtbox.hurt.emit(shock_hitbox)
	shock_hitbox.free()


func _strike_target_from_hurtbox(hurtbox: HurtboxComponent) -> Node:
	var node: Node = hurtbox
	while node != null:
		if node.is_in_group("enemies"):
			return node
		node = node.get_parent()
	return hurtbox.get_parent()


func _has_struck(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var id := target.get_instance_id()
	if not _struck_targets.has(id):
		return false
	var entry: Variant = _struck_targets[id]
	if typeof(entry) == TYPE_DICTIONARY:
		var stored: Node = entry.get("node")
		var until := float(entry.get("until", -1.0))
		if stored != target or not is_instance_valid(stored):
			_struck_targets.erase(id)
			return false
		if until < 0.0:
			return true
		return Time.get_ticks_msec() * 0.001 < until
	# Legacy forever mark
	if entry != target or not is_instance_valid(entry):
		_struck_targets.erase(id)
		return false
	return true


func _mark_struck(target: Node) -> void:
	var until := -1.0
	if _uses_timed_rehit():
		until = Time.get_ticks_msec() * 0.001 + _rehit_cooldown()
	_struck_targets[target.get_instance_id()] = {"node": target, "until": until}


func _prune_struck() -> void:
	if not _uses_timed_rehit():
		return
	var now := Time.get_ticks_msec() * 0.001
	var remove_ids: Array = []
	for id in _struck_targets.keys():
		var entry: Variant = _struck_targets[id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var until := float(entry.get("until", -1.0))
		if until >= 0.0 and now >= until:
			remove_ids.append(id)
	for id in remove_ids:
		_struck_targets.erase(id)


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
		hurtbox.is_invincible = false
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", true)
