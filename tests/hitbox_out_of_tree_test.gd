extends SceneTree
## A hit must be ignored while either box is outside the tree (enemy being
## reparented by a formation break); the overlap is re-reported once it is back.
## XP drop must survive a death that happens outside the tree.

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var hitbox := HitboxComponent.new()
	var hurtbox := HurtboxComponent.new()
	world.add_child(hitbox)
	world.add_child(hurtbox)
	var hits := [0]
	hurtbox.hurt.connect(func(_hitbox) -> void: hits[0] += 1)
	await process_frame

	hitbox._on_hurtbox_entered(hurtbox)
	_expect(hits[0] == 1, "hit lands while both boxes are in the tree")

	world.remove_child(hurtbox)
	hitbox._on_hurtbox_entered(hurtbox)
	_expect(hits[0] == 1, "hit is ignored while the hurtbox is outside the tree")

	world.add_child(hurtbox)
	hitbox._on_hurtbox_entered(hurtbox)
	_expect(hits[0] == 2, "hit lands again once the hurtbox is back in the tree")

	world.remove_child(hitbox)
	hitbox._on_hurtbox_entered(hurtbox)
	_expect(hits[0] == 2, "hit is ignored while the hitbox is outside the tree")
	world.add_child(hitbox)

	# XP drop from a detached actor: must not touch a null tree.
	var drop := ExperienceDropComponent.new()
	var actor := Node2D.new()
	actor.global_position = Vector2(100, 100)
	drop.actor = actor
	drop.orb_scene = load("res://pickups/experience_orb.tscn")
	drop.drop_chance = 1.0
	drop.experience_amount = 3
	drop._on_no_health()
	await process_frame
	await process_frame
	var orbs := world.get_children().filter(func(child): return child is ExperienceOrb)
	_expect(orbs.size() == 1, "detached actor still drops its XP orb into the gameplay world (got %d)" % orbs.size())

	hitbox.queue_free()
	hurtbox.queue_free()
	actor.free()
	drop.free()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS hitbox_out_of_tree_test")
		quit(0)
		return
	for failure in failures:
		printerr("FAIL: ", failure)
	quit(1)
