class_name ThreatMonitor
extends Node

signal sample_updated(sample: Dictionary)

const SCORE_CURVE := 2.2
const SCORE_CURVE_DENOMINATOR := 1.0 - exp(-SCORE_CURVE)
const RECENT_WINDOW_SECONDS := 10.0
const DIRECTION_BIN_COUNT := 8

@export var monitored_root: Node
@export var player: Node2D
@export_range(0.05, 2.0, 0.05, "suffix:s") var sample_interval := 0.2
@export_range(1.0, 5.0, 0.1, "suffix:s") var projectile_lookahead := 1.2
@export_range(0.1, 5.0, 0.1, "suffix:s") var reaction_reference := 1.5
@export_range(1.0, 500.0, 1.0, "suffix: DPS") var reference_dps := 40.0
@export_range(4, 32, 1) var grid_columns := 12
@export_range(4, 48, 1) var grid_rows := 18
@export_range(2.0, 32.0, 1.0, "suffix:px") var projectile_hazard_radius := 10.0
@export_range(0.0, 24.0, 1.0, "suffix:px") var body_hazard_padding := 6.0
@export_range(0.3, 0.8, 0.05) var defense_region_start_ratio := 0.55

var current_threat := 0.0
var smoothed_threat := 0.0
var recent_peak := 0.0
var dose := 0.0
var sample_count := 0
var latest_sample: Dictionary = {}

var _sample_accumulator := 0.0
var _elapsed := 0.0
var _recent_samples: Array[Dictionary] = []


func _ready() -> void:
	assert(monitored_root != null, "ThreatMonitor requires a monitored root.")
	if player == null and monitored_root != null:
		player = monitored_root.get_node_or_null("Ship") as Node2D
	assert(player != null, "ThreatMonitor requires a player node.")


func _process(delta: float) -> void:
	_sample_accumulator += delta
	while _sample_accumulator >= sample_interval:
		_sample_accumulator -= sample_interval
		_take_sample(sample_interval)


func take_sample_now() -> Dictionary:
	_take_sample(sample_interval)
	return latest_sample


func reset_measurements() -> void:
	current_threat = 0.0
	smoothed_threat = 0.0
	recent_peak = 0.0
	dose = 0.0
	sample_count = 0
	latest_sample.clear()
	_recent_samples.clear()
	_elapsed = 0.0
	_sample_accumulator = 0.0


static func score_from_components(
	attack: float,
	space: float,
	reaction: float,
	removal: float,
	pattern: float,
	concurrency: float = 0.0,
) -> float:
	var direct_pressure := (
		0.40 * clampf(attack, 0.0, 1.0)
		+ 0.38 * clampf(space, 0.0, 1.0)
		+ 0.22 * clampf(reaction, 0.0, 1.0)
	)
	var pattern_factor := lerpf(0.5, 1.0, clampf(pattern, 0.0, 1.0))
	var persistence_factor := lerpf(0.85, 1.0, clampf(removal, 0.0, 1.0))
	var concurrency_factor := lerpf(1.0, 1.55, clampf(concurrency, 0.0, 1.0))
	var combined := clampf(
		direct_pressure * pattern_factor * persistence_factor * concurrency_factor,
		0.0,
		1.0,
	)
	return 100.0 * (1.0 - exp(-SCORE_CURVE * combined)) / SCORE_CURVE_DENOMINATOR


func get_history_values() -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for entry in _recent_samples:
		values.append(float(entry.current))
	return values


func _take_sample(delta: float) -> void:
	if monitored_root == null or player == null or not is_instance_valid(player):
		return
	_elapsed += delta
	var enemies := _get_monitored_group(&"enemies")
	var projectiles := _get_monitored_group(&"enemy_projectiles")
	var attack_rate := _estimate_projectile_rate(enemies)
	var pattern_data := _measure_pattern_space(projectiles, enemies)
	var space := float(pattern_data.space)
	var relevant_projectile_count := int(pattern_data.relevant_projectile_count)
	var projectile_relevance := (
		0.15
		if projectiles.is_empty()
		else float(relevant_projectile_count) / float(projectiles.size())
	)
	var configured_pressure := clampf(attack_rate / 12.0, 0.0, 1.0) * projectile_relevance
	var live_density := clampf(float(relevant_projectile_count) / 24.0, 0.0, 1.0)
	var coverage_support := lerpf(0.25, 1.0, space)
	var attack := clampf(0.25 * configured_pressure + 0.75 * live_density * coverage_support, 0.0, 1.0)
	var reaction_data := _measure_reaction(enemies)
	var reaction := float(reaction_data.score)
	var total_hp := _sum_enemy_health(enemies)
	var removal_seconds := total_hp / maxf(1.0, reference_dps)
	var removal := clampf(removal_seconds / 10.0, 0.0, 1.0)
	var pattern := float(pattern_data.pattern)
	var concurrency_data := _measure_concurrency(enemies)
	var concurrency := float(concurrency_data.score)

	current_threat = score_from_components(attack, space, reaction, removal, pattern, concurrency)
	var smoothing_alpha := 1.0 - exp(-delta / 1.0)
	smoothed_threat = lerpf(smoothed_threat, current_threat, smoothing_alpha)
	dose += current_threat * delta
	sample_count += 1

	_recent_samples.append({"time": _elapsed, "current": current_threat})
	while not _recent_samples.is_empty() and float(_recent_samples[0].time) < _elapsed - RECENT_WINDOW_SECONDS:
		_recent_samples.pop_front()
	recent_peak = current_threat
	for entry in _recent_samples:
		recent_peak = maxf(recent_peak, float(entry.current))

	latest_sample = {
		"current": current_threat,
		"smooth": smoothed_threat,
		"peak": recent_peak,
		"dose": dose,
		"attack": attack,
		"space": space,
		"reaction": reaction,
		"removal": removal,
		"pattern": pattern,
		"passive_safe_ratio": float(pattern_data.passive_safe_ratio),
		"fragmentation": float(pattern_data.fragmentation),
		"relevant_projectile_count": relevant_projectile_count,
		"concurrency": concurrency,
		"active_source_count": int(concurrency_data.source_count),
		"threat_family_count": int(concurrency_data.family_count),
		"enemy_count": enemies.size(),
		"projectile_count": projectiles.size(),
		"attack_rate": attack_rate,
		"removal_seconds": removal_seconds,
		"min_reaction_time": float(reaction_data.time),
		"sample_count": sample_count,
	}
	sample_updated.emit(latest_sample)


func _get_monitored_group(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group(group_name):
		var node := candidate as Node
		if node != null and (node == monitored_root or monitored_root.is_ancestor_of(node)):
			result.append(node)
	return result


func _estimate_projectile_rate(enemies: Array[Node]) -> float:
	var total := 0.0
	for enemy in enemies:
		total += _get_enemy_projectile_rate(enemy)
	return total


func _get_enemy_projectile_rate(enemy: Node) -> float:
	var total := 0.0
	if enemy.has_method("get_threat_projectile_rate"):
		total += maxf(0.0, float(enemy.call("get_threat_projectile_rate")))
	for descendant in enemy.find_children("*", "Node", true, false):
		if descendant.has_method("get_threat_projectile_rate"):
			total += maxf(0.0, float(descendant.call("get_threat_projectile_rate")))
	return total


func _measure_concurrency(enemies: Array[Node]) -> Dictionary:
	var source_count := 0
	var families: Dictionary = {}
	for enemy in enemies:
		if not _enemy_has_active_threat(enemy):
			continue
		source_count += 1
		var family := enemy.scene_file_path
		if family.is_empty() and enemy.get_script() != null:
			family = enemy.get_script().resource_path
		if family.is_empty():
			family = enemy.get_class()
		families[family] = true
	var source_load := clampf(float(maxi(0, source_count - 1)) / 6.0, 0.0, 1.0)
	var family_load := clampf(float(maxi(0, families.size() - 1)) / 3.0, 0.0, 1.0)
	return {
		"score": 0.65 * source_load + 0.35 * family_load,
		"source_count": source_count,
		"family_count": families.size(),
	}


func _enemy_has_active_threat(enemy: Node) -> bool:
	if _get_enemy_projectile_rate(enemy) > 0.0:
		return true
	if _node_reports_active_response(enemy):
		return true
	for descendant in enemy.find_children("*", "Node", true, false):
		if _node_reports_active_response(descendant):
			return true
	return false


func _node_reports_active_response(node: Node) -> bool:
	if node.has_method("get_threat_response_pressure"):
		if float(node.call("get_threat_response_pressure")) > 0.0:
			return true
	if node.has_method("get_threat_reaction_time"):
		return float(node.call("get_threat_reaction_time")) >= 0.0
	return false


func _sum_enemy_health(enemies: Array[Node]) -> float:
	var total := 0.0
	for enemy in enemies:
		var stats := enemy.get_node_or_null("StatsComponent") as StatsComponent
		if stats != null:
			total += maxf(0.0, float(stats.health))
	return total


func _measure_pattern_space(projectiles: Array[Node], enemies: Array[Node]) -> Dictionary:
	var viewport_rect := player.get_viewport_rect()
	var defense_top := viewport_rect.position.y + viewport_rect.size.y * defense_region_start_ratio
	var defense_rect := Rect2(
		Vector2(viewport_rect.position.x, defense_top),
		Vector2(viewport_rect.size.x, viewport_rect.end.y - defense_top),
	)
	var projectile_paths: Array[Dictionary] = []
	var direction_bins: Dictionary = {}
	for projectile in projectiles:
		var actor := projectile as Node2D
		if actor == null:
			continue
		var velocity := _get_projectile_velocity(actor)
		if velocity.is_zero_approx():
			continue
		var path_start := actor.global_position
		var path_end := actor.global_position + velocity * projectile_lookahead
		if not _segment_intersects_rect(path_start, path_end, defense_rect.grow(projectile_hazard_radius)):
			continue
		projectile_paths.append({"start": path_start, "end": path_end})
		var normalized_angle := fposmod(velocity.angle(), TAU) / TAU
		var bin_index := mini(DIRECTION_BIN_COUNT - 1, floori(normalized_angle * DIRECTION_BIN_COUNT))
		direction_bins[bin_index] = true
	var bomb_areas: Array[Dictionary] = []
	var body_paths: Array[Dictionary] = []
	for enemy in enemies:
		var actor := enemy as Node2D
		if actor != null:
			var hitbox := actor.get_node_or_null("HitboxComponent") as HitboxComponent
			if hitbox != null and hitbox.collision_mask != 0:
				var move := actor.get_node_or_null("MoveComponent") as MoveComponent
				var velocity := move.velocity if move != null else Vector2.ZERO
				body_paths.append({
					"start": actor.global_position,
					"end": actor.global_position + velocity * projectile_lookahead,
					"radius": _get_body_collision_radius(hitbox) + body_hazard_padding,
				})
		for descendant in enemy.find_children("*", "BombProximityFuseComponent", true, false):
			var fuse := descendant as BombProximityFuseComponent
			if fuse != null and fuse.actor != null:
				bomb_areas.append({"center": fuse.actor.global_position, "radius": fuse.trigger_radius})

	var blocked_cells := PackedByteArray()
	var total_cells := maxi(1, grid_columns * grid_rows)
	blocked_cells.resize(total_cells)
	var blocked := 0
	for row in grid_rows:
		for column in grid_columns:
			var point := Vector2(
				defense_rect.position.x + defense_rect.size.x * (float(column) + 0.5) / float(grid_columns),
				defense_rect.position.y + defense_rect.size.y * (float(row) + 0.5) / float(grid_rows),
			)
			if _is_point_blocked(point, projectile_paths, body_paths, bomb_areas):
				blocked_cells[row * grid_columns + column] = 1
				blocked += 1
	var transitions := 0
	var adjacency_count := 0
	for row in grid_rows:
		for column in grid_columns:
			var cell_index := row * grid_columns + column
			if column + 1 < grid_columns:
				adjacency_count += 1
				if blocked_cells[cell_index] != blocked_cells[cell_index + 1]:
					transitions += 1
			if row + 1 < grid_rows:
				adjacency_count += 1
				if blocked_cells[cell_index] != blocked_cells[cell_index + grid_columns]:
					transitions += 1
	var space := float(blocked) / float(total_cells)
	var fragmentation := float(transitions) / float(maxi(1, adjacency_count))
	var direction_diversity := float(direction_bins.size()) / float(DIRECTION_BIN_COUNT)
	var pattern := clampf(
		space * (0.55 + 0.25 * fragmentation + 0.20 * direction_diversity),
		0.0,
		1.0,
	)
	return {
		"space": space,
		"pattern": pattern,
		"passive_safe_ratio": 1.0 - space,
		"fragmentation": fragmentation,
		"relevant_projectile_count": projectile_paths.size(),
	}


func _get_projectile_velocity(projectile: Node2D) -> Vector2:
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	if move != null:
		return move.velocity
	if projectile.has_method("get_threat_velocity"):
		return projectile.call("get_threat_velocity") as Vector2
	return Vector2.ZERO


func _segment_intersects_rect(start: Vector2, end: Vector2, rect: Rect2) -> bool:
	if rect.has_point(start) or rect.has_point(end):
		return true
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	var bottom_right := rect.end
	return (
		Geometry2D.segment_intersects_segment(start, end, top_left, top_right) != null
		or Geometry2D.segment_intersects_segment(start, end, top_right, bottom_right) != null
		or Geometry2D.segment_intersects_segment(start, end, bottom_right, bottom_left) != null
		or Geometry2D.segment_intersects_segment(start, end, bottom_left, top_left) != null
	)


func _is_point_blocked(
	point: Vector2,
	projectile_paths: Array[Dictionary],
	body_paths: Array[Dictionary],
	bomb_areas: Array[Dictionary],
) -> bool:
	for path in projectile_paths:
		if Geometry2D.get_closest_point_to_segment(point, path.start, path.end).distance_to(point) <= projectile_hazard_radius:
			return true
	for path in body_paths:
		if Geometry2D.get_closest_point_to_segment(point, path.start, path.end).distance_to(point) <= float(path.radius):
			return true
	for area in bomb_areas:
		if point.distance_to(area.center) <= float(area.radius):
			return true
	return false


func _get_body_collision_radius(hitbox: HitboxComponent) -> float:
	var collision := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return 8.0
	var shape := collision.shape
	if shape is RectangleShape2D:
		return 0.5 * maxf(shape.size.x, shape.size.y)
	if shape is CircleShape2D:
		return shape.radius
	if shape is CapsuleShape2D:
		return maxf(shape.radius, shape.height * 0.5)
	return 8.0


func _measure_reaction(enemies: Array[Node]) -> Dictionary:
	var shortest := INF
	var strongest_response := 0.0
	for enemy in enemies:
		if enemy.has_method("get_threat_reaction_time"):
			var enemy_reaction_time := float(enemy.call("get_threat_reaction_time"))
			if enemy_reaction_time >= 0.0:
				shortest = minf(shortest, enemy_reaction_time)
		if enemy.has_method("get_threat_response_pressure"):
			strongest_response = maxf(
				strongest_response,
				clampf(float(enemy.call("get_threat_response_pressure")), 0.0, 1.0),
			)
		for descendant in enemy.find_children("*", "Node", true, false):
			if descendant.has_method("get_threat_reaction_time"):
				var telegraph_time := float(descendant.call("get_threat_reaction_time"))
				if telegraph_time >= 0.0:
					shortest = minf(shortest, telegraph_time)
			if descendant.has_method("get_threat_response_pressure"):
				strongest_response = maxf(
					strongest_response,
					clampf(float(descendant.call("get_threat_response_pressure")), 0.0, 1.0),
				)
	if shortest == INF:
		return {"score": strongest_response, "time": -1.0}
	return {
		"score": maxf(
			strongest_response,
			clampf(1.0 - shortest / reaction_reference, 0.0, 1.0),
		),
		"time": shortest,
	}
