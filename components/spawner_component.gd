# Give the component a class name so it can be instanced as a custom node
class_name SpawnerComponent
extends Node2D

# Export the dependencies for this component
# The scene we want to spawn
@export var scene: PackedScene

# Spawn an instance of the scene at a specific global position on a parent
# By default the parent is the current "main" scene , but you can pass in
# an alternative parent if you so choose.
func spawn(
	global_spawn_position: Vector2 = global_position,
	parent: Node = null,
	configure_before_add: Callable = Callable(),
) -> Node:
	assert(scene is PackedScene, "Error: The scene export was never set on this spawner component.")
	var spawn_parent := parent
	if spawn_parent == null:
		# The owner may die while this spawner is still outside the tree: a
		# formation break reparents the enemy, and the hurtbox re-entering the
		# tree fires area_entered before later siblings (this node) have
		# entered. The spawn parent is the world, not the owner, so resolve the
		# tree through the main loop instead of dereferencing a null tree.
		var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
		assert(tree != null, "SpawnerComponent requires a SceneTree to resolve a spawn parent.")
		spawn_parent = tree.get_first_node_in_group("gameplay_world")
		if spawn_parent == null:
			spawn_parent = tree.current_scene
	assert(spawn_parent != null, "SpawnerComponent requires a spawn parent.")
	# Instance the scene
	var instance = scene.instantiate()
	if configure_before_add.is_valid():
		configure_before_add.call(instance)
	# Add it as a child of the parent
	spawn_parent.add_child(instance)
	# Update the global position of the instance.
	# (This must be done after adding it as a child)
	instance.global_position = global_spawn_position
	# Return the instance in case we want to perform any other operations
	# on it after instancing it.
	return instance
