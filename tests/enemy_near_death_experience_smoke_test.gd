extends SceneTree

const AUGMENT := preload("res://resources/enemy_augments/enemy_near_death_experience.tres")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate() as Node
	var offer_controller := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var registered := false
	for augment in offer_controller.enemy_augment_pool:
		if augment.augment_id == &"enemy_near_death_experience":
			registered = true
			break
	_expect(registered, "near-death augment is registered in the gameplay pool")
	gameplay.free()

	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var registry := EnemyAugmentRegistry.new()
	registry.add_augment(AUGMENT)
	var enemy := load("res://enemies/enemy.tscn").instantiate() as Enemy
	enemy.augment_registry = registry
	world.add_child(enemy)
	await process_frame
	await process_frame

	_expect(
		enemy.get_node_or_null("NearDeathExperienceComponent") != null,
		"active augment attaches near-death behavior",
	)
	var stats := enemy.get_node("StatsComponent") as StatsComponent
	var hurtbox := enemy.get_node("HurtboxComponent") as HurtboxComponent
	var death_state := {"triggers": 0}
	stats.no_health.connect(func() -> void:
		death_state["triggers"] = int(death_state["triggers"]) + 1
	)
	var lethal_hitbox := HitboxComponent.new()
	lethal_hitbox.damage = stats.health
	hurtbox.hurt.emit(lethal_hitbox)
	lethal_hitbox.free()

	_expect(is_instance_valid(enemy), "lethal damage enters near-death instead of freeing enemy")
	_expect(stats.health == 1, "near-death holds enemy at one health")
	_expect(hurtbox.is_invincible, "near-death makes enemy invincible")
	_expect(
		(enemy.get_node("Anchor") as CanvasItem).modulate.a < 0.5,
		"near-death enemy becomes translucent",
	)
	_expect(int(death_state["triggers"]) == 0, "death trigger is delayed during near-death")
	_expect(world.get_node_or_null("ExplosionEffect") == null, "explosion is delayed during near-death")
	var blocked_hitbox := HitboxComponent.new()
	blocked_hitbox.damage = 99
	blocked_hitbox.call("_on_hurtbox_entered", hurtbox)
	_expect(stats.health == 1, "near-death invincibility blocks additional damage")
	blocked_hitbox.free()

	await create_timer(0.5).timeout
	_expect(is_instance_valid(enemy), "enemy remains alive halfway through near-death")
	_expect(int(death_state["triggers"]) == 0, "death remains delayed for the full duration")
	await create_timer(0.6).timeout
	await process_frame
	_expect(int(death_state["triggers"]) == 1, "death trigger fires once after near-death")
	_expect(not is_instance_valid(enemy), "enemy is removed after near-death")
	_expect(world.get_node_or_null("ExplosionEffect") != null, "delayed death spawns explosion")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("enemy_near_death_experience_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("enemy_near_death_experience_smoke_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
