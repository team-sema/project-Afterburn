extends SceneTree

const LAB_SCENE := preload("res://weapon_test/weapon_test_lab.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame

	var enemy_buttons := lab.get_node("%EnemyButtons") as VBoxContainer
	var weapon_buttons := lab.get_node("%WeaponButtons") as VBoxContainer
	_expect(enemy_buttons.get_child_count() == 5, "all five enemy spawn controls are present")
	_expect(weapon_buttons.get_child_count() == 7, "all seven weapon controls are present")

	var gameplay := lab.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/WeaponTestGameplay")
	var ship := gameplay.get_node("Ship")
	var loadout := ship.get_weapon_loadout() as PlayerWeaponLoadout
	_expect(loadout.get_equipped_weapon_ids() == [&"main_blaster"], "test ship starts with the default blaster")

	(enemy_buttons.get_node("Spawn_striker") as Button).pressed.emit()
	await process_frame
	_expect(_count_descendants_in_group(gameplay, &"enemies") == 1, "spawn control creates a target")
	var spawned_enemy := _first_descendant_in_group(gameplay, &"enemies") as Enemy
	var experience_drop := spawned_enemy.get_node("ExperienceDropComponent") as ExperienceDropComponent
	_expect(experience_drop.drop_chance == 0.0, "test targets have experience drops disabled")
	spawned_enemy.stats_component.health = 0
	await process_frame
	await process_frame
	_expect(_count_descendants_of_type(gameplay, ExperienceOrb) == 0, "defeated test targets do not create experience orbs")

	(weapon_buttons.get_node("Weapon_main_laser") as Button).pressed.emit()
	await process_frame
	_expect(loadout.get_bay(0).equipped_weapon_id == &"main_laser", "weapon control replaces the selected bay")

	(lab.get_node("%ClearTargetsButton") as Button).pressed.emit()
	await process_frame
	_expect(_count_descendants_in_group(gameplay, &"enemies") == 0, "clear control removes active targets")

	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("weapon test lab smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon test lab smoke test: %s" % failure)
	quit(1)


func _count_descendants_in_group(parent: Node, group: StringName) -> int:
	var count := 0
	for node in get_nodes_in_group(group):
		if parent.is_ancestor_of(node):
			count += 1
	return count


func _first_descendant_in_group(parent: Node, group: StringName) -> Node:
	for node in get_nodes_in_group(group):
		if parent.is_ancestor_of(node):
			return node
	return null


func _count_descendants_of_type(parent: Node, script_type: Variant) -> int:
	var count := 0
	for child in parent.find_children("*", "", true, false):
		if is_instance_of(child, script_type):
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
