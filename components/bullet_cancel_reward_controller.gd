class_name BulletCancelRewardController
extends Node

const EXPERIENCE_PER_PROJECTILE := 1

@export var gameplay_world: Node2D
@export var experience_collector: Area2D
@export var experience_orb_scene: PackedScene

var is_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	assert(gameplay_world != null, "BulletCancelRewardController requires gameplay_world.")
	assert(experience_collector != null, "BulletCancelRewardController requires experience_collector.")
	assert(experience_orb_scene != null, "BulletCancelRewardController requires experience_orb_scene.")


func collect_projectiles_and_vacuum() -> int:
	assert(not is_active, "Bullet cancel reward cannot overlap itself.")
	is_active = true

	# Enemy shots and elite XP can both be spawned deferred from the same frame
	# as the no_health signal. Drain those additions before scanning so every
	# projectile is converted and every orb joins the same screen-wide vacuum.
	await get_tree().process_frame
	var converted_count := _convert_enemy_projectiles()
	var attracted_orbs := _start_experience_vacuum()
	while _has_live_orb(attracted_orbs):
		if not is_instance_valid(experience_collector):
			break
		await get_tree().process_frame

	is_active = false
	return converted_count


func _convert_enemy_projectiles() -> int:
	var converted_count := 0
	for node in get_tree().get_nodes_in_group("enemy_projectiles"):
		var projectile := node as Node2D
		if (
			projectile == null
			or projectile.is_queued_for_deletion()
			or not gameplay_world.is_ancestor_of(projectile)
		):
			continue
		var orb := experience_orb_scene.instantiate() as ExperienceOrb
		assert(orb != null, "Bullet cancel reward requires an ExperienceOrb scene.")
		gameplay_world.add_child(orb)
		orb.setup(EXPERIENCE_PER_PROJECTILE, projectile.global_position)
		projectile.queue_free()
		converted_count += 1
	return converted_count


func _start_experience_vacuum() -> Array[ExperienceOrb]:
	var attracted_orbs: Array[ExperienceOrb] = []
	for node in get_tree().get_nodes_in_group("experience_orbs"):
		var orb := node as ExperienceOrb
		if orb == null or not gameplay_world.is_ancestor_of(orb):
			continue
		if orb.start_forced_attraction(experience_collector):
			attracted_orbs.append(orb)
	return attracted_orbs


func _has_live_orb(orbs: Array[ExperienceOrb]) -> bool:
	for orb in orbs:
		if is_instance_valid(orb):
			return true
	return false
