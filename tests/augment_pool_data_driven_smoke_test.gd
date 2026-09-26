extends SceneTree

## Verifies offer pools come from folder scan (not gameplay.tscn inline lists).

const COUNTER_SHOT := preload("res://resources/enemy_augments/enemy_counter_shot_on_hit.tres")
const DRONE_REINFORCEMENT := preload(
	"res://resources/enemy_augments/enemy_drone_formation_reinforcement.tres"
)


var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_pool := AugmentPoolLoader.load_player_offer_pool()
	var enemy_pool := AugmentPoolLoader.load_enemy_offer_pool()
	_expect(player_pool.size() == 57, "player offer pool scans 57 cards")
	_expect(enemy_pool.size() == 6, "enemy offer pool scans 6 cards")
	_expect(enemy_pool.has(DRONE_REINFORCEMENT), "drone reinforcement is in offer pool")
	_expect(not enemy_pool.has(COUNTER_SHOT), "counter shot stays out of offer pool")

	var gameplay := (load("res://gameplay.tscn") as PackedScene).instantiate()
	root.add_child(gameplay)
	await process_frame
	var offer := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	_expect(offer.player_augment_pool.size() == 57, "gameplay auto-loads 57 player cards")
	_expect(offer.enemy_augment_pool.size() == 6, "gameplay auto-loads 6 enemy cards")
	_expect(
		offer.enemy_augment_pool.has(DRONE_REINFORCEMENT),
		"gameplay enemy pool includes drone reinforcement",
	)
	_expect(
		not offer.enemy_augment_pool.has(COUNTER_SHOT),
		"gameplay enemy pool excludes counter shot",
	)
	gameplay.queue_free()
	await process_frame

	if failures.is_empty():
		print("PASS augment_pool_data_driven_smoke_test")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL augment_pool_data_driven_smoke_test (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
