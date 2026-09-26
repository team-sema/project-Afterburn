extends SceneTree

const TRAIT_DIR := "res://resources/weapons/traits"
const CARD_DIR := "res://resources/player_augments/weapon"
## Silver 14 + Gold 21 + Prismatic 1.
const EXPECTED_TRAIT_COUNTS := [14, 21, 1]
const MAX_RANK_BY_TIER := [5, 3, 1]

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tier_counts := [0, 0, 0]
	var definitions: Dictionary = {}
	for file_name in DirAccess.get_files_at(TRAIT_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var definition := load("%s/%s" % [TRAIT_DIR, file_name]) as WeaponTraitDefinition
		_expect(definition != null, "%s loads as a weapon module" % file_name)
		if definition == null:
			continue
		definitions[definition.trait_id] = definition
		var tier := int(definition.tier)
		tier_counts[tier] += 1
		var max_rank: int = MAX_RANK_BY_TIER[tier]
		_expect(
			definition.max_rank == max_rank,
			"%s %s module has max Lv.%d" % [definition.trait_id, PlayerAugment.tier_label(tier as PlayerAugment.Tier), max_rank],
		)
		_expect(
			definition.rank_overrides.size() == max_rank - 1,
			"%s provides one override per level above Lv.I" % definition.trait_id,
		)
		for rank in range(1, max_rank + 1):
			var text := definition.format_description(rank)
			_expect(
				text != "" and not text.contains("{") and not text.contains("}"),
				"%s Lv.%d description fills every placeholder" % [definition.trait_id, rank],
			)
			_expect(not text.contains("→"), "%s Lv.%d alone shows no change arrow" % [definition.trait_id, rank])
			if rank == 1:
				continue
			_expect(
				definition.get_params_for_rank(rank) != definition.get_params_for_rank(rank - 1),
				"%s Lv.%d changes combat params" % [definition.trait_id, rank],
			)
			_expect(
				definition.format_description(rank, rank - 1).contains("→"),
				"%s Lv.%d card marks the values that change" % [definition.trait_id, rank],
			)

	for tier in 3:
		_expect(
			tier_counts[tier] == EXPECTED_TRAIT_COUNTS[tier],
			"%d %s weapon modules (got %d)" % [
				EXPECTED_TRAIT_COUNTS[tier],
				PlayerAugment.tier_label(tier as PlayerAugment.Tier),
				tier_counts[tier],
			],
		)

	# Every module has a card whose tier matches the module definition.
	var carded: Dictionary = {}
	for file_name in DirAccess.get_files_at(CARD_DIR):
		if not file_name.begins_with("trait_") or not file_name.ends_with(".tres"):
			continue
		var card := load("%s/%s" % [CARD_DIR, file_name]) as PlayerAugment
		if card == null or card.trait_definition == null:
			_expect(false, "%s links a module definition" % file_name)
			continue
		carded[card.trait_id] = true
		_expect(
			card.tier == card.trait_definition.tier,
			"%s card tier matches its module tier" % card.augment_id,
		)
		_expect(
			card.augment_id == StringName("trait_%s" % card.trait_id),
			"%s card id follows trait_<trait_id>" % card.augment_id,
		)
	for trait_id in definitions:
		_expect(carded.has(trait_id), "%s has an offer card" % trait_id)

	for weapon_id in [
		&"main_blaster",
		&"main_laser",
		&"main_shotgun",
		&"aux_test_cannon",
		&"plasma_bomb",
		&"aux_homing_missile",
		&"aux_orbital_barrier",
	]:
		var power := definitions.get(StringName("%s_power" % weapon_id)) as WeaponTraitDefinition
		_expect(
			power != null and power.tier == PlayerAugment.Tier.SILVER and power.target_weapon_id == weapon_id,
			"%s has a silver power module" % weapon_id,
		)

	var heat := definitions[&"laser_heat_stack"] as WeaponTraitDefinition
	_expect(
		heat.format_description(1) == "같은 적 연속 조사 0.5초마다 피해 +15%(최대 +90%).",
		"percent placeholders render value ×100",
	)
	_expect(
		heat.format_description(2, 1) == "같은 적 연속 조사 0.5초마다 피해 +15→20%(최대 +90→120%).",
		"only changed values render as current→next",
	)

	if failures.is_empty():
		print("weapon_module_rank_data_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("weapon_module_rank_data_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
