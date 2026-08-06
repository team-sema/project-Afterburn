extends SceneTree

const TRAIT_DIR := "res://resources/weapons/traits"
const EXPECTED_TRAIT_COUNT := 28

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var files := DirAccess.get_files_at(TRAIT_DIR)
	var trait_count := 0
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var definition := load("%s/%s" % [TRAIT_DIR, file_name]) as WeaponTraitDefinition
		_expect(definition != null, "%s loads as a weapon module" % file_name)
		if definition == null:
			continue
		trait_count += 1
		_expect(definition.max_rank == 3, "%s has max Lv.III" % definition.trait_id)
		_expect(
			definition.rank_overrides.size() == 2,
			"%s provides Lv.II and Lv.III overrides" % definition.trait_id,
		)
		var level_one := definition.get_params_for_rank(1)
		var level_two := definition.get_params_for_rank(2)
		var level_three := definition.get_params_for_rank(3)
		_expect(level_two != level_one, "%s Lv.II changes combat params" % definition.trait_id)
		_expect(level_three != level_two, "%s Lv.III changes combat params" % definition.trait_id)

	_expect(trait_count == EXPECTED_TRAIT_COUNT, "all 28 weapon modules are levelled")

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
