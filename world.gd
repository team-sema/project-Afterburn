extends Node2D

@export var game_stats: GameStats

@onready var ship: Node2D = $Ship


func _ready() -> void:
	game_stats.score = 0
	randomize()

	if not is_node_ready():
		await ready

	ship.tree_exited.connect(func():
		if not is_inside_tree():
			return
		var tree := get_tree()
		if tree == null:
			return
		await tree.create_timer(1.0).timeout
		if not is_inside_tree():
			return
		get_tree().change_scene_to_file("uid://dku528fh63hdb")
	)
