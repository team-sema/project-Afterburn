extends SceneTree

const LAB_SCENE := preload("res://weapon_test/weapon_test_lab.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := LAB_SCENE.instantiate() as WeaponTestLab
	root.add_child(lab)
	await process_frame
	await process_frame

	var enemy_buttons := lab.get_node("%EnemyButtons") as VBoxContainer
	var weapon_buttons := lab.get_node("%WeaponButtons") as VBoxContainer
	var trait_buttons := lab.get_node("%TraitButtons") as VBoxContainer
	var reference_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")),
	)
	var minimum_size: Vector2 = lab.get_combined_minimum_size()
	_expect(
		minimum_size.x <= reference_size.x and minimum_size.y <= reference_size.y,
		"lab minimum size %s fits the reference viewport %s" % [minimum_size, reference_size],
	)
	for panel_path in ["Layout/LeftPanel", "Layout/RightPanel"]:
		var panel := lab.get_node(panel_path) as Control
		var panel_rect := panel.get_global_rect()
		_expect(
			panel_rect.position.x >= 0.0
			and panel_rect.position.y >= 0.0
			and panel_rect.end.x <= reference_size.x
			and panel_rect.end.y <= reference_size.y,
			"%s stays inside the reference viewport" % panel_path,
		)
	_expect(enemy_buttons.get_child_count() == 5, "all five enemy spawn controls are present")
	_expect(weapon_buttons.get_child_count() == 7, "all seven weapon controls are present")
	_expect(trait_buttons.get_child_count() == 4, "default blaster exposes its four traits")
	_expect(lab.get_player_augment_count() == 12, "all 12 facility augments are discovered")
	_expect(
		lab.get_enemy_augment_count() == 7,
		"all seven enemy augments include the gameplay-unregistered resource",
	)

	var gameplay := lab.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/WeaponTestGameplay")
	var ship := gameplay.get_node("Ship")
	var loadout := ship.get_weapon_loadout() as PlayerWeaponLoadout
	var player_registry := gameplay.get_node("PlayerAugmentRegistry") as PlayerAugmentRegistry
	var enemy_registry := gameplay.get_node("EnemyAugmentRegistry") as EnemyAugmentRegistry
	_expect(loadout.get_equipped_weapon_ids() == [&"main_blaster"], "test ship starts with the default blaster")

	var player_level_events := [0]
	lab.player_level_up_simulated.connect(func(_level: int) -> void: player_level_events[0] += 1)
	var player_key := InputEventKey.new()
	player_key.pressed = true
	player_key.physical_keycode = KEY_C
	lab._unhandled_key_input(player_key)
	_expect(player_level_events[0] == 1, "C simulates one player level-up event")
	_expect(lab.is_augment_picker_open(), "C opens the player augment picker")
	var player_augment_buttons := lab.find_children("Player_*", "Button", true, false)
	_expect(player_augment_buttons.size() == 12, "player picker renders one row per facility augment")
	for node in player_augment_buttons:
		var augment_button := node as Button
		_expect(
			augment_button.icon == null and augment_button.get_combined_minimum_size().y <= 50.0,
			"%s keeps a compact icon-independent row height" % augment_button.name,
		)
	_expect(
		lab.find_child("Player_trait_laser_pulse", true, false) == null,
		"player picker excludes weapon augments handled by the loadout panel",
	)
	var engine_augment_button := lab.find_child("Player_facility_engine", true, false) as Button
	_expect(engine_augment_button != null, "player picker includes facility augments")
	if engine_augment_button != null:
		engine_augment_button.pressed.emit()
	_expect(
		player_registry.get_stack_count(&"facility_engine") == 1,
		"player picker installs the selected augment",
	)
	_expect(not lab.is_augment_picker_open(), "player picker closes after a successful choice")

	var enemy_events := [0]
	lab.enemy_augment_event_simulated.connect(func(_tier: int) -> void: enemy_events[0] += 1)
	var enemy_key := InputEventKey.new()
	enemy_key.pressed = true
	enemy_key.physical_keycode = KEY_V
	lab._unhandled_key_input(enemy_key)
	_expect(enemy_events[0] == 1, "V simulates one enemy augment event")
	_expect(lab.is_augment_picker_open(), "V opens the enemy augment picker")
	var counter_shot_button := (
		lab.find_child("Enemy_enemy_counter_shot_on_hit", true, false) as Button
	)
	_expect(counter_shot_button != null, "enemy picker includes the unregistered counter-shot augment")
	if counter_shot_button != null:
		counter_shot_button.pressed.emit()
	_expect(
		enemy_registry.get_stack_count(&"enemy_counter_shot_on_hit") == 1,
		"enemy picker applies the selected augment",
	)
	_expect(not lab.is_augment_picker_open(), "enemy picker closes after a successful choice")
	lab.open_enemy_augment_picker()
	var drone_reinforcement_button := (
		lab.find_child("Enemy_enemy_drone_formation_reinforcement", true, false) as Button
	)
	_expect(drone_reinforcement_button != null, "enemy picker includes spawn-count augments")
	if drone_reinforcement_button != null:
		drone_reinforcement_button.pressed.emit()
	(enemy_buttons.get_node("Enemy_drone_formation/Spawn_drone_formation") as Button).pressed.emit()
	await process_frame
	_expect(
		_count_descendants_in_group(gameplay, &"enemies") == 6,
		"drone reinforcement adds one enemy to the five-drone lab formation",
	)
	(lab.get_node("%ClearTargetsButton") as Button).pressed.emit()
	await process_frame

	(enemy_buttons.get_node("Enemy_striker/Spawn_striker") as Button).pressed.emit()
	await process_frame
	_expect(_count_descendants_in_group(gameplay, &"enemies") == 1, "spawn control creates a target")
	var spawned_enemy := _first_descendant_in_group(gameplay, &"enemies") as Enemy
	var experience_drop := spawned_enemy.get_node("ExperienceDropComponent") as ExperienceDropComponent
	_expect(experience_drop.drop_chance == 0.0, "test targets have experience drops disabled")
	spawned_enemy.stats_component.health = 0
	await process_frame
	await process_frame
	_expect(_count_descendants_of_type(gameplay, ExperienceOrb) == 0, "defeated test targets do not create experience orbs")

	var ricochet_button := trait_buttons.get_node("Trait_blaster_ricochet") as Button
	ricochet_button.pressed.emit()
	_expect(
		int(loadout.get_weapon_traits(&"main_blaster").get(&"blaster_ricochet", 0)) == 1,
		"trait control enables the selected weapon trait",
	)
	ricochet_button.pressed.emit()
	_expect(
		loadout.get_weapon_traits(&"main_blaster").is_empty(),
		"active trait control disables the trait again",
	)
	ricochet_button.pressed.emit()
	(trait_buttons.get_node("Trait_blaster_accel_ap") as Button).pressed.emit()
	(lab.get_node("%ClearTraitsButton") as Button).pressed.emit()
	_expect(
		loadout.get_weapon_traits(&"main_blaster").is_empty(),
		"clear trait control removes every trait from the selected weapon",
	)

	var repeat_striker := enemy_buttons.get_node("Enemy_striker/Repeat_striker") as CheckButton
	var continuous_button := lab.get_node("%ContinuousSpawnButton") as Button
	var continuous_timer := lab.get_node("%ContinuousSpawnTimer") as Timer
	repeat_striker.button_pressed = true
	repeat_striker.toggled.emit(true)
	continuous_button.button_pressed = true
	continuous_button.toggled.emit(true)
	continuous_timer.timeout.emit()
	await process_frame
	_expect(
		_count_descendants_in_group(gameplay, &"enemies") == 1,
		"continuous mode spawns each selected enemy pattern",
	)
	continuous_button.button_pressed = false
	continuous_button.toggled.emit(false)
	continuous_timer.timeout.emit()
	await process_frame
	_expect(
		_count_descendants_in_group(gameplay, &"enemies") == 1,
		"stopped continuous mode ignores later timer ticks",
	)

	var weapon_ids: Array[StringName] = [
		&"main_blaster",
		&"main_laser",
		&"main_shotgun",
		&"aux_test_cannon",
		&"plasma_bomb",
		&"aux_homing_missile",
		&"aux_orbital_barrier",
	]
	for weapon_id in weapon_ids:
		(weapon_buttons.get_node("Weapon_%s" % String(weapon_id)) as Button).pressed.emit()
		await process_frame
		_expect(
			loadout.get_bay(0).equipped_weapon_id == weapon_id,
			"weapon control equips %s" % String(weapon_id),
		)
		_expect(
			trait_buttons.get_child_count() == 4,
			"%s exposes its four traits" % String(weapon_id),
		)
		for child in trait_buttons.get_children():
			var definition := child.get_meta("definition") as WeaponTraitDefinition
			_expect(
				definition != null and definition.target_weapon_id == weapon_id,
				"trait controls only show %s traits" % String(weapon_id),
			)

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
