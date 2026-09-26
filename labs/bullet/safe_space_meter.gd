class_name SafeSpaceMeter
extends Node

## Lab diagnostic: share of the lower defense region a stationary player
## could occupy without being hit within the lookahead window.

@export var monitored_root: Node
@export var player: Node2D
@export_range(0.05, 2.0, 0.05, "suffix:s") var sample_interval := 0.2
@export_range(1.0, 5.0, 0.1, "suffix:s") var lookahead := 1.2
@export_range(4, 32, 1) var grid_columns := 12
@export_range(4, 48, 1) var grid_rows := 18
@export_range(2.0, 32.0, 1.0, "suffix:px") var projectile_hazard_radius := 10.0
@export_range(0.0, 24.0, 1.0, "suffix:px") var body_hazard_padding := 6.0
@export_range(0.3, 0.8, 0.05) var defense_region_start_ratio := 0.55

var passive_safe_ratio := 1.0
var relevant_projectile_count := 0
var sample_count := 0

var _sample_accumulator := 0.0


func _process(delta: float) -> void:
	_sample_accumulator += delta
	while _sample_accumulator >= sample_interval:
		_sample_accumulator -= sample_interval
		measure()


func reset_measurements() -> void:
	passive_safe_ratio = 1.0
	relevant_projectile_count = 0
	sample_count = 0
	_sample_accumulator = 0.0


func measure() -> float:
	if monitored_root == null or player == null or not is_instance_valid(player):
		return passive_safe_ratio
	passive_safe_ratio = 1.0 - _measure_blocked_ratio(
		_get_monitored_group(&"enemy_projectiles"),
		_get_monitored_group(&"enemies"),
	)
	sample_count += 1
	return passive_safe_ratio


func get_defense_rect() -> Rect2:
	var viewport_rect := player.get_viewport_rect()
	var defense_top := viewport_rect.position.y + viewport_rect.size.y * defense_region_start_ratio
	return Rect2(
		Vector2(viewport_rect.position.x, defense_top),
		Vector2(viewport_rect.size.x, viewport_rect.end.y - defense_top),
	)


func _get_monitored_group(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group(group_name):
		var node := candidate as Node
		if node != null and (node == monitored_root or monitored_root.is_ancestor_of(node)):
			result.append(node)
	return result


func _measure_blocked_ratio(projectiles: Array[Node], enemies: Array[Node]) -> float:
	var defense_rect := get_defense_rect()
	var projectile_paths: Array[Dictionary] = []
	relevant_projectile_count = 0
	for projectile in projectiles:
		var actor := projectile as Node2D
		if actor == null or actor.is_queued_for_deletion():
			continue
		var points := PackedVector2Array()
		var radius := projectile_hazard_radius
		if actor.has_method("get_predicted_path"):
			points = actor.call("get_predicted_path", lookahead)
			if actor.has_method("get_hazard_radius"):
				radius = float(actor.call("get_hazard_radius")) + body_hazard_padding
		else:
			var velocity := _get_projectile_velocity(actor)
			if not velocity.is_zero_approx():
				points = PackedVector2Array([actor.global_position, actor.global_position + velocity * lookahead])
		var relevant := false
		for index in range(1, points.size()):
			if _segment_intersects_rect(points[index - 1], points[index], defense_rect.grow(radius)):
				projectile_paths.append({"start": points[index - 1], "end": points[index], "radius": radius})
				relevant = true
		if relevant:
			relevant_projectile_count += 1
	var body_paths: Array[Dictionary] = []
	var bomb_areas: Array[Dictionary] = []
	for enemy in enemies:
		var actor := enemy as Node2D
		if actor != null:
			var hitbox := actor.get_node_or_null("HitboxComponent") as HitboxComponent
			if hitbox != null and hitbox.collision_mask != 0:
				var move := actor.get_node_or_null("MoveComponent") as MoveComponent
				var velocity := move.velocity if move != null else Vector2.ZERO
				body_paths.append({
					"start": actor.global_position,
					"end": actor.global_position + velocity * lookahead,
					"radius": _get_body_collision_radius(hitbox) + body_hazard_padding,
				})
		for descendant in enemy.find_children("*", "BombProximityFuseComponent", true, false):
			var fuse := descendant as BombProximityFuseComponent
			if fuse != null and fuse.actor != null:
				bomb_areas.append({"center": fuse.actor.global_position, "radius": fuse.trigger_radius})

	var total_cells := maxi(1, grid_columns * grid_rows)
	var blocked_cells := PackedByteArray()
	blocked_cells.resize(total_cells)
	# Rasterize only cells within each swept segment's expanded bounds.
	var cell_size := defense_rect.size / Vector2(grid_columns, grid_rows)
	for path in projectile_paths:
		var start: Vector2 = path.start
		var end: Vector2 = path.end
		var radius: float = path.radius
		var low := (start.min(end) - Vector2.ONE * radius - defense_rect.position) / cell_size - Vector2.ONE * 0.5
		var high := (start.max(end) + Vector2.ONE * radius - defense_rect.position) / cell_size - Vector2.ONE * 0.5
		for row in range(maxi(0, ceili(low.y)), mini(grid_rows - 1, floori(high.y)) + 1):
			for column in range(maxi(0, ceili(low.x)), mini(grid_columns - 1, floori(high.x)) + 1):
				var index := row * grid_columns + column
				if blocked_cells[index] != 0:
					continue
				var center := defense_rect.position + Vector2(column + 0.5, row + 0.5) * cell_size
				if Geometry2D.get_closest_point_to_segment(center, start, end).distance_squared_to(center) <= radius * radius:
					blocked_cells[index] = 1
	var blocked := 0
	for row in grid_rows:
		for column in grid_columns:
			var index := row * grid_columns + column
			var center := defense_rect.position + Vector2(column + 0.5, row + 0.5) * cell_size
			if blocked_cells[index] != 0 or _is_point_blocked(center, body_paths, bomb_areas):
				blocked += 1
	return float(blocked) / float(total_cells)


func _get_projectile_velocity(projectile: Node2D) -> Vector2:
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	if move != null:
		return move.velocity
	if projectile.has_method("get_travel_velocity"):
		return projectile.call("get_travel_velocity") as Vector2
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


func _is_point_blocked(point: Vector2, body_paths: Array[Dictionary], bomb_areas: Array[Dictionary]) -> bool:
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
