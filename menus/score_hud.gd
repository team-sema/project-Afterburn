class_name ScoreHud
extends Label

@export var game_stats: GameStats


func _ready() -> void:
	assert(game_stats != null, "ScoreHud requires GameStats.")
	game_stats.score_changed.connect(_update_score)
	_update_score(game_stats.score)


func _update_score(score: int) -> void:
	text = "%06d" % score
