class_name OrbitalBarrierWeaponSystem
extends WeaponSystem

@export var orbit_radius := 22.0
@export var base_orbit_speed := 2.8
@export var base_damage := 6
## Capsule half-width (radial thickness of the shield plate).
@export var segment_thickness := 4.5
## Capsule length along the orbit (short plate face).
@export var segment_arc_length := 12.0
@export_range(0.05, 5.0, 0.05) var base_rehit_cooldown := 1.0
@export_range(10.0, 400.0, 1.0) var knockback_strength := 140.0
## Damage a segment can absorb before it breaks.
@export_range(1, 40, 1) var segment_integrity := 1
## Seconds before a broken segment respawns at full integrity.
@export_range(0.25, 30.0, 0.05) var respawn_delay := 3.0
@export var impact_profile: ImpactProfile = preload("res://effects/impact_profiles/orbital_barrier.tres")

## Plate texture: X = orbit length, Y = radial thickness.
const BASE_GLOW_SCALE := Vector2(0.055, 0.1)
const BASE_CORE_SCALE := Vector2(0.045, 0.075)

@onready var orbit_root: Node2D = $OrbitRoot

var _segments: Array[Node2D] = []
## Enemies already struck: id -> {node, until}  until<0 means forever (no rehit trait).
var _struck_targets: Dictionary = {}
## segment instance_id -> {hp, broken, respawn_at}
var _segment_states: Dictionary = {}
var _template_segment: Node2D
var _base_segment_count := 0
## Gameplay seconds accumulated from _process delta. Respawn and rehit deadlines
## use this so tree pause (augment pick, bullet cancel) freezes them with the run.
var _clock := 0.0


func _ready() -> void:
	_capture_template()
	_layout_segments()
	_wire_segments()
	_apply_stat_multipliers()


func _process(delta: float) -> void:
	_clock += delta
	_update_respawns()
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
		_restore_segment(segment)


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
		_restore_segment(clone)
	while _segments.size() > desired:
		var extra := _segments.pop_back() as Node2D
		if is_instance_valid(extra):
			_segment_states.erase(extra.get_instance_id())
			if extra != _template_segment:
				extra.queue_free()
	_layout_segments()
	_apply_stat_multipliers()
	for segment in _segments:
		if not _is_segment_broken(segment):
			_enable_segment_collision(segment)


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
		# Local +X is tangential (orbit face width); +Y is radial.
		var face_scale := Vector2(size_mult, size_mult)
		var glow := segment.get_node_or_null("Glow") as Sprite2D
		if glow != null:
			glow.scale = BASE_GLOW_SCALE * face_scale
		var core := segment.get_node_or_null("Core") as Sprite2D
		if core != null:
			core.scale = BASE_CORE_SCALE * face_scale


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
		# Capsule height is local Y; rotate so the long axis follows the orbit tangent (local X).
		shape_node.rotation = PI * 0.5
		shape_node.shape = capsule


func _wire_segments() -> void:
	for segment in _segments:
		_wire_one_segment(segment)
		_restore_segment(segment)


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
	var hurt_bound := _on_segment_hurt.bind(segment)
	if not hurtbox.hurt.is_connected(hurt_bound):
		hurtbox.hurt.connect(hurt_bound)
	_enable_segment_collision(segment)


func _ensure_segment_state(segment: Node2D) -> Dictionary:
	var id := segment.get_instance_id()
	if not _segment_states.has(id):
		_segment_states[id] = {
			"hp": segment_integrity,
			"broken": false,
			"respawn_at": -1.0,
		}
	return _segment_states[id]


func _is_segment_broken(segment: Node2D) -> bool:
	if segment == null or not is_instance_valid(segment):
		return true
	return bool(_ensure_segment_state(segment).get("broken", false))


func get_segment_integrity(segment: Node2D) -> int:
	return int(_ensure_segment_state(segment).get("hp", 0))


func is_segment_broken(segment: Node2D) -> bool:
	return _is_segment_broken(segment)


func _on_segment_hurt(hitbox: Variant, segment: Node2D) -> void:
	if segment == null or not is_instance_valid(segment):
		return
	if _is_segment_broken(segment):
		return
	var damage := 1
	if hitbox is HitboxComponent:
		damage = maxi(1, (hitbox as HitboxComponent).damage)
	var state := _ensure_segment_state(segment)
	state["hp"] = int(state.get("hp", segment_integrity)) - damage
	if int(state["hp"]) <= 0:
		_break_segment(segment)


func _break_segment(segment: Node2D) -> void:
	var state := _ensure_segment_state(segment)
	state["hp"] = 0
	state["broken"] = true
	state["respawn_at"] = _clock + respawn_delay
	_disable_segment_collision(segment)
	_set_segment_visible(segment, false)


func _restore_segment(segment: Node2D) -> void:
	if segment == null or not is_instance_valid(segment):
		return
	var state := _ensure_segment_state(segment)
	state["hp"] = segment_integrity
	state["broken"] = false
	state["respawn_at"] = -1.0
	_set_segment_visible(segment, true)
	if not is_shutdown:
		_enable_segment_collision(segment)


func _update_respawns() -> void:
	var now := _clock
	for segment in _segments:
		if segment == null or not is_instance_valid(segment):
			continue
		var state := _ensure_segment_state(segment)
		if not bool(state.get("broken", false)):
			continue
		var respawn_at := float(state.get("respawn_at", -1.0))
		if respawn_at >= 0.0 and now >= respawn_at:
			_restore_segment(segment)


func _set_segment_visible(segment: Node2D, enabled: bool) -> void:
	for child in segment.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = enabled


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
	var segment := hitbox.get_parent() as Node2D
	if segment != null and _is_segment_broken(segment):
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
	if segment != null:
		# Contact sits between the segment and the enemy; sparks bounce back
		# toward the barrier.
		ImpactVfx.emit_from(
			self,
			segment.global_position.lerp(enemy_hurtbox.global_position, 0.5),
			impact_profile,
			segment.global_position - enemy_hurtbox.global_position,
		)

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
		return _clock < until
	# Legacy forever mark
	if entry != target or not is_instance_valid(entry):
		_struck_targets.erase(id)
		return false
	return true


func _mark_struck(target: Node) -> void:
	var until := -1.0
	if _uses_timed_rehit():
		until = _clock + _rehit_cooldown()
	_struck_targets[target.get_instance_id()] = {"node": target, "until": until}


func _prune_struck() -> void:
	if not _uses_timed_rehit():
		return
	var now := _clock
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
	if _is_segment_broken(segment):
		return
	var hitbox := segment.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox != null:
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
	var hurtbox := segment.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		hurtbox.is_invincible = false
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", true)
