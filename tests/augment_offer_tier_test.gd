extends SceneTree

## Offer-level tiers: one tier per offer, lower-tier fill, reroll keeps tier,
## prismatic cap, and the elite kill Gold guarantee.

const SPLIT_PRISM := &"trait_blaster_split_prism"
const FOURTH_BAY := &"prism_fourth_weapon_bay"

var failures: PackedStringArray = []


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	_run.call_deferred()


func _run() -> void:
	var world := load("res://world.tscn").instantiate() as Control
	root.add_child(world)
	var gameplay := world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay")
	var offer := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var progression := gameplay.get_node("AugmentProgressionController") as AugmentProgressionController
	for _i in 4:
		await process_frame

	_set_tier_weights(offer, 0.0, 100.0, 0.0)
	for _n in 30:
		var picks := offer._pick_player_choices()
		_expect(picks.size() == 3, "gold offer still returns three cards")
		_expect(_all_tier(picks, PlayerAugment.Tier.GOLD), "a gold offer only holds gold cards")
		_expect(offer.current_offer_tier == PlayerAugment.Tier.GOLD, "gold offer reports its tier")

	_set_tier_weights(offer, 100.0, 0.0, 0.0)
	for _n in 30:
		_expect(_all_tier(offer._pick_player_choices(), PlayerAugment.Tier.SILVER), "a silver offer only holds silver cards")

	# Only two prismatic cards exist: the third slot falls back to Gold.
	_set_tier_weights(offer, 0.0, 0.0, 100.0)
	var prism_picks := offer._pick_player_choices()
	var ids := prism_picks.map(func(augment: PlayerAugment) -> StringName: return augment.augment_id)
	_expect(ids.has(SPLIT_PRISM) and ids.has(FOURTH_BAY), "prismatic offer shows both prismatic cards")
	_expect(_count_tier(prism_picks, PlayerAugment.Tier.GOLD) == 1, "prismatic shortfall fills from Gold")
	_expect(offer.current_offer_tier == PlayerAugment.Tier.PRISMATIC, "prismatic offer reports its tier")
	_expect(
		PlayerAugment.tier_label(offer.current_offer_tier) == "PRISMATIC",
		"offer title label names the tier",
	)
	var split_card := load("res://resources/player_augments/weapon/trait_blaster_split_prism.tres") as PlayerAugment
	_expect(
		split_card.get_offer_title(null) == "연쇄 분열탄\n블래스터 전용",
		"level-less prismatic card names its weapon instead of a level",
	)

	offer.prismatic_pick_count = offer.max_prismatic_picks_per_run
	var capped := offer._pick_player_choices()
	_expect(_all_tier(capped, PlayerAugment.Tier.GOLD), "the run prismatic cap turns prismatic offers into gold")
	offer.prismatic_pick_count = 0

	# Elite guarantee lifts exactly one Silver roll to Gold.
	_set_tier_weights(offer, 100.0, 0.0, 0.0)
	offer.grant_gold_offer_guarantee()
	_expect(_all_tier(offer._pick_player_choices(), PlayerAugment.Tier.GOLD), "guaranteed offer is Gold")
	_expect(_all_tier(offer._pick_player_choices(), PlayerAugment.Tier.SILVER), "guarantee is used up by one offer")

	# The elite kill path grants it. Keep the offer busy so no overlay opens.
	offer.is_offer_active = true
	progression.elite_gate_active = true
	progression.active_elite_threat = progression.get_threat_level() + 1
	_expect(
		progression.complete_elite_milestone(progression.active_elite_threat),
		"elite milestone completes",
	)
	_expect(offer.pending_gold_guarantees == 1, "an elite kill grants one Gold guarantee")
	offer.is_offer_active = false
	progression.pending_offers.clear()
	offer.pending_gold_guarantees = 0

	# Reroll keeps the focused card's tier.
	_set_tier_weights(offer, 0.0, 100.0, 0.0)
	var baseline := offer._pick_player_choices()
	offer._current_player_choices = baseline.duplicate()
	offer.is_offer_active = true
	offer.active_offer_type = AugmentOfferController.OfferType.PLAYER
	offer._awaiting_final_choice = true
	offer.remaining_reroll_count = 2
	offer.selection_ui._set_choices(baseline)
	offer._on_reroll_requested(0)
	var rerolled := offer._current_player_choices[0]
	_expect(
		rerolled != null and rerolled.augment_id != baseline[0].augment_id,
		"reroll replaces the focused card",
	)
	_expect(rerolled.tier == PlayerAugment.Tier.GOLD, "reroll keeps the gold tier")
	offer.is_offer_active = false
	offer._awaiting_final_choice = false

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("augment_offer_tier_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("augment_offer_tier_test: %s" % failure)
	quit(1)


func _set_tier_weights(offer: AugmentOfferController, silver: float, gold: float, prismatic: float) -> void:
	offer.silver_offer_weight = silver
	offer.gold_offer_weight = gold
	offer.prismatic_offer_weight = prismatic


func _all_tier(picks: Array[PlayerAugment], tier: PlayerAugment.Tier) -> bool:
	return not picks.is_empty() and _count_tier(picks, tier) == picks.size()


func _count_tier(picks: Array[PlayerAugment], tier: PlayerAugment.Tier) -> int:
	var count := 0
	for pick in picks:
		if pick.tier == tier:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
