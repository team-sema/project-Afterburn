extends SceneTree

const WORLD_SCENE := preload("res://world.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var acquire_plasma := load("res://resources/player_augments/weapon/acquire_plasma_bomb.tres")
	var plasma_expand := load("res://resources/weapons/traits/plasma_expand.tres") as WeaponTraitDefinition
	var plasma_bomb := load("res://resources/weapons/definitions/plasma_bomb.tres")
	var drop_table := load("res://resources/weapons/default_weapon_drop_table.tres")
	_expect(is_equal_approx(acquire_plasma.offer_weight, 1.0), "plasma acquire keeps default offer weight")
	_expect(acquire_plasma.weapon_definition == plasma_bomb, "plasma acquire keeps its weapon link")
	_expect(plasma_expand.max_rank == 3, "plasma module supports three levels")
	_expect(
		is_equal_approx(float(plasma_expand.get_param_for_rank(3, &"radius_mult")), 2.2),
		"plasma module keeps its Lv.III override",
	)
	_expect(drop_table.weapons.has(plasma_bomb), "default drop table keeps plasma bomb")

	var world := WORLD_SCENE.instantiate() as Control
	root.add_child(world)
	for _index in 2:
		await process_frame
	var playfield_viewport := world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport") as SubViewport
	var playfield_value := world.get_node("Layout/LeftPanel/Margin/VBox/PlayfieldValue") as Label
	var ship_panel := world.get_node("Layout/RightPanel/Margin/VBox/ShipPanel") as Control
	_expect(
		playfield_viewport.size == Vector2i(240, 360),
		"playfield viewport is 240x360 (got %s)" % playfield_viewport.size,
	)
	_expect(playfield_value.text == "240 × 360", "HUD matches the playfield viewport size")
	_expect(ship_panel.custom_minimum_size.y == 105.0, "world ShipPanel inherits compact honeycomb height")
	_expect(ship_panel.clip_contents, "world ShipPanel inherits clipping")
	world.queue_free()
	await process_frame
	acquire_plasma = null
	plasma_expand = null
	plasma_bomb = null
	drop_table = null

	if failures.is_empty():
		print("Godot editor updates test: PASS")
		quit()
		return
	for failure in failures:
		push_error("Godot editor updates test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
