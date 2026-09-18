class_name OverchargeVisualComponent
extends Node

## Tints a projectile or persistent weapon visual while the periodic reactor
## overcharge is active. Base colors are retained per render node and restored.

const BUFF_CONTROLLER_GROUP := &"player_combat_buff_controllers"
const BUFF_OVERCHARGE := &"overcharge"
## Overbright red keeps cyan/green weapon art luminous instead of multiplying it
## down to near-black. Alpha always comes from the original visual.
const OVERCHARGE_TINT := Color(4.0, 0.16, 0.08, 1.0)

@export var visual_root: Node
## Projectiles keep the spawn-time state. Persistent weapons such as the laser
## and orbital barrier opt in so their visuals follow buff start/end live.
@export var follow_buff_state_changes := false
## Only persistent visuals that add render nodes at runtime (the multi-segment
## barrier) need the global node-added hook. Projectile scenes keep this off.
@export var track_dynamic_descendants := false

var _buff_controller: Node
var _tracked_visuals: Dictionary = {}
var _overcharge_active := false


func _ready() -> void:
	if visual_root == null:
		visual_root = get_parent()
	assert(visual_root != null, "OverchargeVisualComponent requires a visual root.")
	_capture_branch(visual_root)
	if track_dynamic_descendants and not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	_bind_buff_controller(get_tree().get_first_node_in_group(BUFF_CONTROLLER_GROUP))
	if _buff_controller == null:
		call_deferred("_find_buff_controller")


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	_disconnect_buff_controller()


func _bind_buff_controller(controller: Node) -> void:
	if controller == null or controller == _buff_controller:
		return
	_disconnect_buff_controller()
	_buff_controller = controller
	if follow_buff_state_changes and controller.has_signal(&"buff_state_changed"):
		controller.connect(&"buff_state_changed", _refresh_buff_state)
	_refresh_buff_state()


func _find_buff_controller() -> void:
	if not is_inside_tree() or _buff_controller != null:
		return
	_bind_buff_controller(get_tree().get_first_node_in_group(BUFF_CONTROLLER_GROUP))


func _disconnect_buff_controller() -> void:
	if _buff_controller != null and is_instance_valid(_buff_controller):
		if follow_buff_state_changes and _buff_controller.has_signal(&"buff_state_changed"):
			var callback := Callable(self, "_refresh_buff_state")
			if _buff_controller.is_connected(&"buff_state_changed", callback):
				_buff_controller.disconnect(&"buff_state_changed", callback)
	_buff_controller = null


func _refresh_buff_state() -> void:
	var active := false
	if _buff_controller != null and is_instance_valid(_buff_controller):
		if _buff_controller.has_method("is_buff_active"):
			active = bool(_buff_controller.call("is_buff_active", BUFF_OVERCHARGE))
	_set_overcharge_active(active)


func _set_overcharge_active(active: bool) -> void:
	_overcharge_active = active
	var stale_ids: Array = []
	for instance_id in _tracked_visuals:
		var entry := _tracked_visuals[instance_id] as Dictionary
		var item := entry.get("node") as CanvasItem
		if item == null or not is_instance_valid(item):
			stale_ids.append(instance_id)
			continue
		var base_color := entry.get("self_modulate", Color.WHITE) as Color
		item.self_modulate = _tinted(base_color) if active else base_color
	for instance_id in stale_ids:
		_tracked_visuals.erase(instance_id)


func _capture_branch(node: Node) -> void:
	_capture_visual(node)
	for child in node.get_children():
		_capture_branch(child)


func _capture_visual(node: Node) -> void:
	if not _is_render_visual(node):
		return
	var item := node as CanvasItem
	var instance_id := item.get_instance_id()
	if _tracked_visuals.has(instance_id):
		return
	var base_color := item.self_modulate
	_tracked_visuals[instance_id] = {
		"node": item,
		"self_modulate": base_color,
	}
	if _overcharge_active:
		item.self_modulate = _tinted(base_color)


func _is_render_visual(node: Node) -> bool:
	if node is Sprite2D or node is Line2D or node is Polygon2D:
		return true
	if node is GPUParticles2D or node is CPUParticles2D or node is MeshInstance2D:
		return true
	# Covers leaf custom-draw nodes such as LaserRefractVfx without tinting a
	# projectile's parent Node2D and multiplying all descendants twice.
	return node is CanvasItem and node.get_script() != null and node.get_child_count() == 0


func _on_tree_node_added(node: Node) -> void:
	if visual_root != null and (node == visual_root or visual_root.is_ancestor_of(node)):
		_capture_visual(node)


func _tinted(base_color: Color) -> Color:
	return Color(
		base_color.r * OVERCHARGE_TINT.r,
		base_color.g * OVERCHARGE_TINT.g,
		base_color.b * OVERCHARGE_TINT.b,
		base_color.a,
	)
