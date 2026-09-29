class_name EnemyBullets
extends RefCounted

## Shared access to live enemy bullets for player effects and augments.
## Every enemy bullet body joins GROUP. FoundationBullet, CurvedLaser and the
## legacy projectile also put their hitbox on physics LAYER; SniperBullet keeps a
## non-monitorable hitbox, so query_shape skips it (query_circle/cancel still work).
## Query and cancel through here instead of walking the group directly, so every
## removal reports a reason on the world's EnemyBulletHub.

const GROUP := &"enemy_projectiles"
## Physics layer 4 (`enemy_projectile`). Bullet hitboxes are monitorable on it;
## nothing masks it by default, so only explicit queries see bullets.
const LAYER := 1 << 3
const HUB_NAME := &"EnemyBulletHub"
const QUERY_BATCH := 64

## Cancel reasons used by the game. Any StringName is accepted.
const REASON_AUGMENT_RESUME := &"augment_resume"
const REASON_ELITE_REWARD := &"elite_reward"
const REASON_BOSS := &"boss"
const REASON_LAB := &"lab"


## Live bullets under `world`, excluding ones already queued for deletion.
static func get_all(world: Node) -> Array[Node2D]:
	var bullets: Array[Node2D] = []
	if world == null or not world.is_inside_tree():
		return bullets
	for node in world.get_tree().get_nodes_in_group(GROUP):
		var bullet := node as Node2D
		if _is_live(world, bullet):
			bullets.append(bullet)
	return bullets


## Bullets whose centre (laser: head) lies within `radius` of `center`.
static func query_circle(world: Node, center: Vector2, radius: float) -> Array[Node2D]:
	var hits: Array[Node2D] = []
	var radius_squared := radius * radius
	for bullet in get_all(world):
		if center.distance_squared_to(bullet.global_position) <= radius_squared:
			hits.append(bullet)
	return hits


## Bullets whose hitbox overlaps `shape` placed at `shape_transform` (global).
## Uses physics, so a laser body counts wherever its segments overlap.
## Newly spawned bullets appear after their first physics frame.
static func query_shape(world: Node2D, shape: Shape2D, shape_transform: Transform2D) -> Array[Node2D]:
	var hits: Array[Node2D] = []
	if world == null or not world.is_inside_tree() or shape == null:
		return hits
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = shape_transform
	query.collision_mask = LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen: Dictionary = {}
	var exclude: Array[RID] = []
	var space := world.get_world_2d().direct_space_state
	while true:
		query.exclude = exclude
		var batch := space.intersect_shape(query, QUERY_BATCH)
		for result in batch:
			exclude.append(result["rid"])
			var bullet := _bullet_from_collider(result.get("collider") as Node)
			if bullet == null or seen.has(bullet.get_instance_id()) or not _is_live(world, bullet):
				continue
			seen[bullet.get_instance_id()] = true
			hits.append(bullet)
		if batch.size() < QUERY_BATCH:
			break
	return hits


## Removes one bullet and reports it on the world's hub. Returns false when the
## bullet is not a live bullet under `world`.
static func cancel(world: Node, bullet: Node2D, reason: StringName) -> bool:
	if not _is_live(world, bullet):
		return false
	var hub := world.get_node_or_null(NodePath(HUB_NAME)) as EnemyBulletHub
	if hub != null:
		hub.bullet_cancelled.emit(bullet.global_position, reason, bullet)
	bullet.queue_free()
	return true


## Cancels every bullet in `bullets`; returns how many were removed.
static func cancel_all(world: Node, bullets: Array, reason: StringName) -> int:
	var count := 0
	for bullet in bullets:
		if cancel(world, bullet as Node2D, reason):
			count += 1
	return count


## Signal source for cancellations under `world`, created on first use.
static func get_hub(world: Node) -> EnemyBulletHub:
	var hub := world.get_node_or_null(NodePath(HUB_NAME)) as EnemyBulletHub
	if hub == null:
		hub = EnemyBulletHub.new()
		hub.name = HUB_NAME
		world.add_child(hub)
	return hub


static func _is_live(world: Node, bullet: Node2D) -> bool:
	return (
		bullet != null
		and is_instance_valid(bullet)
		and not bullet.is_queued_for_deletion()
		and bullet.is_in_group(GROUP)
		and world != null
		and world.is_ancestor_of(bullet)
	)


static func _bullet_from_collider(collider: Node) -> Node2D:
	var node := collider
	while node != null:
		if node.is_in_group(GROUP):
			return node as Node2D
		node = node.get_parent()
	return null
