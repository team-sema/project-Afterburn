extends SceneTree

const CONFIG := preload("res://resources/enemy_movement/default_movement_space.tres")
const ZIGZAG := preload("res://resources/enemy_movement/sequences/zigzag.tres")
const ZIGZAG_PRESET := preload(
	"res://resources/encounters/presets/drone_zigzag_formation.tres"
)

var failures := PackedStringArray()
var registry: EnemyAugmentRegistry


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	registry = EnemyAugmentRegistry.new()
	root.add_child(registry)

	_test_space_relationships_and_resize()
	await _test_diagonal_crosses_visible_edge_and_reenters()
	await _test_enemy_uses_despawn_area()
	await _test_offscreen_formation_entry_maneuver_exit()

	registry.queue_free()
	await process_frame
	if failures.is_empty():
		print("movement_space_smoke_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("movement_space_smoke_test: %s" % failure)
	quit(1)


func _test_space_relationships_and_resize() -> void:
	_expect(CONFIG.validate(), "default MovementSpaceConfig validates")
	var visible := Rect2(Vector2.ZERO, Vector2(240, 360))
	var movement := CONFIG.get_movement_area(visible)
	var combat := CONFIG.get_combat_area(visible)
	var despawn := CONFIG.get_despawn_area(visible)
	_expect(movement.encloses(visible), "MovementArea encloses VisibleRect")
	_expect(despawn.encloses(movement), "DespawnArea encloses MovementArea")
	_expect(visible.encloses(combat), "VisibleRect encloses explicit CombatArea")
	_expect(is_equal_approx(movement.position.x, -48.0), "movement margin is viewport-relative")

	var resized := Rect2(Vector2(20, 10), Vector2(400, 300))
	var resized_movement := CONFIG.get_movement_area(resized)
	_expect(
		is_equal_approx(resized.position.x - resized_movement.position.x, 80.0),
		"MovementArea recomputes from a resized viewport",
	)
	_expect(
		CONFIG.get_despawn_area(resized).encloses(resized_movement),
		"resized DespawnArea still encloses MovementArea",
	)


func _test_diagonal_crosses_visible_edge_and_reenters() -> void:
	var playfield := SubViewport.new()
	playfield.size = Vector2i(240, 360)
	root.add_child(playfield)
	var actor := Node2D.new()
	var move := MoveComponent.new()
	move.actor = actor
	var controller := MovementController.new()
	controller.actor = actor
	controller.move_component = move
	controller.auto_start = false
	actor.add_child(move)
	actor.add_child(controller)
	playfield.add_child(actor)
	var visible := actor.get_viewport_rect()
	actor.global_position = Vector2(visible.end.x - 10.0, visible.get_center().y)

	var diagonal := BoundedDiagonalMovementStep.new()
	diagonal.forward_speed = 72.0
	diagonal.angle_degrees = 50.0
	diagonal.edge_margin = 8.0
	var sequence := MovementSequence.new()
	sequence.steps.append(diagonal)
	controller.set_sequence(sequence, {"formation_direction": Vector2.RIGHT})
	controller.start()
	controller.set_process(false)
	controller.update_movement(0.3)
	var first_outside := actor.global_position
	controller.update_movement(0.3)
	var continued_outward := actor.global_position
	_expect(first_outside.x > visible.end.x, "diagonal path crosses VisibleRect without clamping")
	_expect(
		continued_outward.x > first_outside.x,
		"constant diagonal continues after crossing the camera edge",
	)
	_expect(
		CONFIG.get_despawn_area(visible).has_point(continued_outward),
		"offscreen turn remains inside DespawnArea",
	)
	controller.update_movement(0.4)
	_expect(actor.global_position.x > visible.end.x, "turn happens outside VisibleRect in MovementArea")
	controller.update_movement(0.7)
	_expect(
		actor.global_position.x < visible.end.x,
		"expanded-area diagonal naturally re-enters the camera",
	)

	playfield.queue_free()
	await process_frame


func _test_enemy_uses_despawn_area() -> void:
	var enemy := (load("res://enemies/normal_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.augment_registry = registry
	root.add_child(enemy)
	var notifier := enemy.get_node("VisibleOnScreenNotifier2D") as FreeOffscreenComponent
	var visible := enemy.get_viewport_rect()
	enemy.global_position = Vector2(visible.end.x + 12.0, visible.get_center().y)
	notifier._process(0.0)
	await process_frame
	_expect(is_instance_valid(enemy), "leaving VisibleRect does not immediately remove an Enemy")
	if not is_instance_valid(enemy):
		return
	var despawn := CONFIG.get_despawn_area(visible)
	enemy.global_position = Vector2(
		despawn.end.x + notifier.actor_extent_padding + 1.0,
		visible.get_center().y,
	)
	notifier._process(0.0)
	await process_frame
	_expect(not is_instance_valid(enemy), "Enemy is removed after fully leaving DespawnArea")


func _test_offscreen_formation_entry_maneuver_exit() -> void:
	var playfield := SubViewport.new()
	playfield.size = Vector2i(240, 360)
	root.add_child(playfield)
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	playfield.add_child(world)
	var spawner := EnemySpawner.new()
	spawner.augment_registry = registry
	spawner.spawn_parent = world
	world.add_child(spawner)
	var left_entry := ZIGZAG_PRESET.duplicate(true) as EncounterPreset
	left_entry.spawn_anchor = EncounterPreset.SpawnAnchor.TOP_LEFT
	var controller := spawner.spawn_encounter(left_entry) as FormationController
	var visible := controller.get_viewport_rect()
	var start := controller.global_position
	_expect(start.x < visible.position.x, "zigzag Encounter can spawn left of VisibleRect")
	_expect(start.y < visible.position.y, "zigzag Encounter enters from above VisibleRect")
	await process_frame
	await process_frame
	controller.set_process(false)
	controller.center_movement_controller.set_process(false)
	var original_offsets: Dictionary = {}
	for member in controller.get_members():
		original_offsets[member.get_instance_id()] = controller.to_local(member.global_position)

	controller.center_movement_controller.update_movement(0.6)
	controller.call("_update_member_positions", 0.6)
	_expect(
		controller.global_position.x >= visible.position.x,
		"offscreen formation crosses into the visible width on a constant diagonal",
	)
	for member in controller.get_members():
		_expect(
			controller.to_local(member.global_position).is_equal_approx(
				original_offsets[member.get_instance_id()] as Vector2
			),
			"offscreen formation member keeps its authored slot offset",
		)

	controller.center_movement_controller.update_movement(4.1)
	controller.call("_update_member_positions", 4.1)
	_expect(
		controller.global_position.x > visible.end.x,
		"formation turns only after leaving VisibleRect for MovementArea",
	)
	controller.center_movement_controller.update_movement(1.0)
	controller.call("_update_member_positions", 1.0)
	_expect(
		visible.has_point(controller.global_position),
		"formation re-enters while preserving its constant diagonal path",
	)

	# Continuous descent acts as EXIT; DespawnArea removes members only after the
	# full formation has travelled well beyond the camera.
	# Advance in frame-sized chunks so bounded reflection and offscreen cleanup
	# exercise the same path they use during gameplay.
	for _index in 18:
		if not is_instance_valid(controller):
			break
		controller.center_movement_controller.update_movement(0.5)
		controller.call("_update_member_positions", 0.5)
		await process_frame
	if is_instance_valid(controller):
		controller.set_process(true)
	for _index in 8:
		await process_frame
	_expect(not is_instance_valid(controller), "exit beyond DespawnArea cleans up formation members and controller")

	if is_instance_valid(controller):
		controller.queue_free()
	playfield.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
