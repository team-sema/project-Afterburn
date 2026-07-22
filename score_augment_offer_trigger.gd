class_name ScoreAugmentOfferTrigger
extends Node

@export var game_stats: GameStats
@export var offer_controller: AugmentOfferController
@export_range(1, 100000, 1) var first_offer_score := 50
@export_range(1, 100000, 1) var score_interval := 50

var next_offer_score: int
var pending_offer_count := 0


func _ready() -> void:
	assert(game_stats != null, "ScoreAugmentOfferTrigger requires GameStats.")
	assert(offer_controller != null, "ScoreAugmentOfferTrigger requires an AugmentOfferController.")
	next_offer_score = first_offer_score
	game_stats.score_changed.connect(_on_score_changed)
	offer_controller.offer_completed.connect(_on_offer_completed)


func _on_score_changed(new_score: int) -> void:
	while new_score >= next_offer_score:
		pending_offer_count += 1
		next_offer_score += score_interval
	_try_request_offer()


func _try_request_offer() -> void:
	if pending_offer_count <= 0:
		return
	if offer_controller.request_offer():
		pending_offer_count -= 1


func _on_offer_completed(_player_augment: PlayerAugment, _enemy_augment: EnemyAugment) -> void:
	_try_request_offer.call_deferred()
