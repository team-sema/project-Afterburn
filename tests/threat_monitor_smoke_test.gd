extends SceneTree

const LAB_SCENE := preload("res://threat_monitor/threat_monitor_lab.tscn")
const THREAT_MONITOR_SCRIPT := preload("res://threat_monitor/threat_monitor.gd")
const DRONE_PRESET := preload("res://resources/encounters/presets/drone_straight_formation.tres")
const ENEMY_PROJECTILE_SCENE := preload("res://projectiles/base_enemy_projectile.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame

	var monitor: Node = lab.get_node("ThreatMonitor")
	var gameplay: Node = lab.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var ship := gameplay.get_node("Ship") as Node2D
	var hurtbox := ship.get_node("PlayerHitPoint/HurtboxComponent") as HurtboxComponent
	_expect(monitor != null, "lab owns one threat monitor")
	_expect(hurtbox.is_invincible, "monitor play keeps the ship alive")
	_expect(is_equal_approx(THREAT_MONITOR_SCRIPT.score_from_components(0, 0, 0, 0, 0), 0.0), "zero components produce zero threat")
	_expect(is_equal_approx(THREAT_MONITOR_SCRIPT.score_from_components(1, 1, 1, 1, 1), 100.0), "full components produce 100 threat")
	_expect(is_equal_approx(THREAT_MONITOR_SCRIPT.score_from_components(0, 0, 0, 1, 1, 1), 0.0), "multipliers cannot create threat without direct pressure")
	_expect(
		THREAT_MONITOR_SCRIPT.score_from_components(0.4, 0.3, 0.4, 0.3, 0.3, 1.0)
		> THREAT_MONITOR_SCRIPT.score_from_components(0.4, 0.3, 0.4, 0.3, 0.3, 0.0),
		"concurrent threats increase an existing direct pressure",
	)

	var initial: Dictionary = monitor.take_sample_now()
	_expect(int(initial.enemy_count) == 0, "empty playfield starts with no monitored enemies")
	_expect(float(initial.current) == 0.0, "empty playfield starts at zero threat")

	var outside_projectile := Node2D.new()
	outside_projectile.add_to_group("enemy_projectiles")
	root.add_child(outside_projectile)
	var outside_sample: Dictionary = monitor.take_sample_now()
	_expect(int(outside_sample.projectile_count) == 0, "nodes outside the monitored root are ignored")
	outside_projectile.queue_free()

	var generator: Node = gameplay.get_node("EnemyGenerator")
	generator.spawn_preset_tracked(DRONE_PRESET)
	await process_frame
	await process_frame
	var active: Dictionary = monitor.take_sample_now()
	_expect(int(active.enemy_count) == 5, "one drone formation contributes all five members")
	_expect(float(active.attack_rate) > 0.0, "drone fire configuration contributes expected projectile rate")
	_expect(float(active.removal) > 0.0, "enemy health contributes removal pressure")
	_expect(int(active.active_source_count) == 5, "five firing drones are counted as concurrent sources")
	_expect(float(active.concurrency) > 0.0, "multiple firing drones contribute concurrency pressure")
	_expect(float(active.current) > 0.0, "live encounter raises current threat")
	_expect((lab.get_node("%CurrentValue") as Label).text != "000.0", "HUD receives live monitor samples")
	_expect(lab.get_node_or_null("%ThreatGraph") != null, "lab exposes the recent history graph")
	_expect(lab.get_node_or_null("%RestartButton") != null, "lab exposes a restart control")
	for candidate in get_nodes_in_group(&"enemies"):
		var contact_enemy := candidate as Node2D
		if contact_enemy != null and gameplay.is_ancestor_of(contact_enemy):
			contact_enemy.global_position = Vector2(120.0, 300.0)
			break
	var contact_sample: Dictionary = monitor.take_sample_now()
	_expect(float(contact_sample.space) > 0.0, "contact-damage bodies contribute occupied defense space")

	var projectile := ENEMY_PROJECTILE_SCENE.instantiate() as Node2D
	projectile.position = Vector2(120.0, 120.0)
	gameplay.add_child(projectile)
	projectile.call("launch", Vector2.DOWN, 105.0)
	await process_frame
	var before_move: Dictionary = monitor.take_sample_now()
	_expect(int(before_move.relevant_projectile_count) >= 1, "projectiles entering the defense region are counted")
	_expect(float(before_move.passive_safe_ratio) > 0.5, "a sparse shot leaves most stationary positions safe")
	_expect(before_move.has("fragmentation"), "sample reports safe-space fragmentation")
	ship.position = Vector2(200.0, 300.0)
	var after_move: Dictionary = monitor.take_sample_now()
	_expect(
		is_equal_approx(float(before_move.current), float(after_move.current)),
		"player movement alone does not change intrinsic threat",
	)

	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")),
	)
	var layout := lab.get_node("Layout") as Control
	var playfield := lab.get_node("Layout/Playfield") as Control
	var sub_viewport := lab.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport") as SubViewport
	var detail_min: Vector2 = lab.get_node("Layout/DetailPanel").get_combined_minimum_size()
	var summary_min: Vector2 = lab.get_node("Layout/SummaryPanel").get_combined_minimum_size()
	_expect(
		layout.size.x <= viewport_size.x + 0.5 and layout.size.y <= viewport_size.y + 0.5,
		"monitor lab layout %s fits viewport %s" % [layout.size, viewport_size],
	)
	_expect(
		detail_min.y <= viewport_size.y and summary_min.y <= viewport_size.y,
		"side panels min height detail=%s summary=%s fit viewport height %s" % [detail_min.y, summary_min.y, viewport_size.y],
	)
	_expect(
		is_equal_approx(playfield.size.x, 240.0) and is_equal_approx(playfield.size.y, 360.0),
		"playfield stays 240x360 (got %s)" % playfield.size,
	)
	_expect(
		sub_viewport.size == Vector2i(240, 360),
		"playfield SubViewport stays 240x360 (got %s)" % sub_viewport.size,
	)

	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("threat monitor smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
