class_name BulletCancelRewardController
extends Node

## Elite/boss kill reward. Runs while the game keeps going (no tree pause):
## enemy bullets inside VisibleRect (+ margin) turn into XP orbs, the rest are
## cancelled without XP, then every XP orb on the field is pulled into the ship.
## When fewer bullets convert than the kill's minimum, the shortfall pops out
## as 1 XP orbs around the kill position and joins the same vacuum.
## Waits until those orbs are collected, or until the cap collects stragglers.

const EXPERIENCE_PER_PROJECTILE := 1

@export var gameplay_world: Node2D
@export var experience_collector: Area2D
@export var experience_orb_scene: PackedScene
## Bullets this far outside VisibleRect still count as on screen.
@export_range(0.0, 200.0, 1.0) var visible_margin := 16.0
## Gameplay seconds after the vacuum starts at which remaining orbs are
## collected on the spot. Above ExperienceOrb.forced_arrival_time (0.6 s).
@export_range(0.1, 10.0, 0.05) var collect_cap_time := 1.0
## Minimum-reward orbs scatter within this radius of the kill position.
@export_range(0.0, 64.0, 1.0) var minimum_burst_radius := 18.0

var is_active := false
## Bullets cancelled without an orb by the last reward (off screen).
var last_discarded_count := 0
## Orbs added at the kill position by the last reward's minimum XP.
var last_minimum_bonus_count := 0


func _ready() -> void:
	assert(gameplay_world != null, "BulletCancelRewardController requires gameplay_world.")
	assert(experience_collector != null, "BulletCancelRewardController requires experience_collector.")
	assert(experience_orb_scene != null, "BulletCancelRewardController requires experience_orb_scene.")


## Returns how many bullets became XP orbs. `minimum_experience` tops the
## converted count up with orbs at `burst_origin`; converted bullets at or above
## it add nothing. The defeated enemy's own guaranteed drop never counts.
func collect_projectiles_and_vacuum(minimum_experience := 0, burst_origin := Vector2.ZERO) -> int:
	assert(not is_active, "Bullet cancel reward cannot overlap itself.")
	is_active = true
	last_discarded_count = 0
	last_minimum_bonus_count = 0

	# Enemy shots and elite XP can both be spawned deferred from the same frame
	# as the no_health signal. Drain those additions before scanning so every
	# projectile is converted and every orb joins the same vacuum.
	await _await_process_frame()
	var converted_count := 0
	if _can_run_vacuum():
		converted_count = _convert_enemy_projectiles()
		last_minimum_bonus_count = _spawn_minimum_bonus(
			maxi(0, minimum_experience - converted_count),
			burst_origin,
		)
		var attracted_orbs := _start_experience_vacuum()
		# Gameplay-time timer: a manual pause freezes both the orbs and the cap.
		var cap_timer := get_tree().create_timer(collect_cap_time, false)
		while _has_live_orb(attracted_orbs):
			if not _can_run_vacuum():
				break
			if cap_timer.time_left <= 0.0:
				_collect_remaining(attracted_orbs)
				break
			await _await_process_frame()

	is_active = false
	return converted_count


## False once the ship (and its collector) is gone, e.g. it died mid-reward.
func has_live_collector() -> bool:
	return is_instance_valid(experience_collector) and experience_collector.is_inside_tree()


## World-space VisibleRect grown by visible_margin.
func get_conversion_rect() -> Rect2:
	var viewport := gameplay_world.get_viewport()
	var visible_rect := viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	return visible_rect.grow(visible_margin)


func _can_run_vacuum() -> bool:
	return is_inside_tree() and is_instance_valid(gameplay_world) and has_live_collector()


func _await_process_frame() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame


func _convert_enemy_projectiles() -> int:
	var converted_count := 0
	if not is_inside_tree() or not is_instance_valid(gameplay_world):
		return 0
	var conversion_rect := get_conversion_rect()
	for projectile in EnemyBullets.get_all(gameplay_world):
		# Lasers and beams are judged by their origin, like EnemyBullets queries.
		if conversion_rect.has_point(projectile.global_position):
			var orb := experience_orb_scene.instantiate() as ExperienceOrb
			assert(orb != null, "Bullet cancel reward requires an ExperienceOrb scene.")
			gameplay_world.add_child(orb)
			orb.setup(EXPERIENCE_PER_PROJECTILE, projectile.global_position)
			converted_count += 1
		else:
			last_discarded_count += 1
		EnemyBullets.cancel(gameplay_world, projectile, EnemyBullets.REASON_ELITE_REWARD)
	return converted_count


func _spawn_minimum_bonus(count: int, origin: Vector2) -> int:
	for i in count:
		var orb := experience_orb_scene.instantiate() as ExperienceOrb
		assert(orb != null, "Bullet cancel reward requires an ExperienceOrb scene.")
		gameplay_world.add_child(orb)
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.3, 1.0) * minimum_burst_radius
		orb.setup(EXPERIENCE_PER_PROJECTILE, origin + offset)
	return count


func _start_experience_vacuum() -> Array[ExperienceOrb]:
	var attracted_orbs: Array[ExperienceOrb] = []
	if not _can_run_vacuum():
		return attracted_orbs
	# Typed Area2D args reject previously-freed objects before the callee body runs,
	# so validate the collector here rather than only inside ExperienceOrb.
	var collector := experience_collector
	for node in get_tree().get_nodes_in_group("experience_orbs"):
		if not is_instance_valid(collector):
			break
		var orb := node as ExperienceOrb
		if orb == null or not is_instance_valid(orb) or not gameplay_world.is_ancestor_of(orb):
			continue
		if orb.start_forced_attraction(collector):
			attracted_orbs.append(orb)
	return attracted_orbs


func _collect_remaining(orbs: Array[ExperienceOrb]) -> void:
	for orb in orbs:
		if is_instance_valid(orb) and not orb.is_queued_for_deletion():
			orb.collect_now()


func _has_live_orb(orbs: Array[ExperienceOrb]) -> bool:
	for orb in orbs:
		if is_instance_valid(orb) and not orb.is_queued_for_deletion():
			return true
	return false
