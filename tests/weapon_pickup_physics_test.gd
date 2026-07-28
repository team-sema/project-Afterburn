extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_scene: PackedScene = load("res://world.tscn")
	var world: Control = world_scene.instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var ship: Node2D = gameplay.get_node("Ship") as Node2D

	var pickup_scene: PackedScene = load("res://pickups/weapon_pickup.tscn")
	var pickup: Area2D = pickup_scene.instantiate() as Area2D
	gameplay.add_child(pickup)
	var weapon_definition: Resource = load("res://resources/weapons/definitions/aux_orbital_barrier.tres")
	pickup.call("setup", weapon_definition, ship.global_position)

	for _index in 5:
		await physics_frame
		await process_frame

	var loadout: Node = ship.call("get_weapon_loadout")
	if loadout.call("has_auxiliary_weapon", &"aux_orbital_barrier"):
		print("weapon pickup physics test: PASS")
		quit()
		return
	push_error("weapon pickup physics test: auxiliary weapon was not equipped")
	quit(1)
