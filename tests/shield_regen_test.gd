extends SceneTree

## 실드 충전: 깎이면 진행도를 자동 충전·그레이즈로 채우고, 1칸이면 +1, 피격 시 리셋.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shield := ShieldComponent.new()
	shield.base_max_shield = 1
	shield.regen_charge_duration = 1.0
	root.add_child(shield)
	await process_frame

	_expect(shield.get_current_shield() == 1, "starts at full shield 1")
	_expect(is_equal_approx(shield.get_charge_progress(), 0.0), "no charge while full")
	_expect(not shield.is_processing(), "regen idle while full")

	_expect(shield.absorb_damage(1) == 0, "1 dmg vs shield 1 → no hull overflow")
	_expect(shield.get_current_shield() == 0, "shield emptied")
	_expect(shield.is_processing(), "regen starts when below max")

	shield.restore_shield(1)
	_expect(shield.absorb_damage(3) == 2, "3 dmg vs shield 1 → overflow 2 to hull")
	_expect(shield.get_current_shield() == 0, "shield emptied by partial absorb")

	shield.notify_hit()
	_expect(is_equal_approx(shield.get_charge_progress(), 0.0), "hit resets charge")

	shield._process(0.4)
	_expect(is_equal_approx(shield.get_charge_progress(), 0.4), "charge advances over time")
	_expect(shield.get_current_shield() == 0, "partial charge does not restore yet")

	shield.notify_hit()
	_expect(is_equal_approx(shield.get_charge_progress(), 0.0), "second hit resets mid-charge")

	shield._process(1.0)
	_expect(shield.get_current_shield() == 1, "full charge restores +1")
	_expect(is_equal_approx(shield.get_charge_progress(), 0.0), "charge clears at max")
	_expect(not shield.is_processing(), "regen stops at max")

	# Elapsed-near-duration must still restore (old 0~1 clamp approx could stall).
	_expect(shield.absorb_damage(1) == 0, "second empty for near-duration case")
	shield.set("_charge_progress", 0.999995)
	shield.set_process(true)
	shield._process(1.0 / 60.0)
	_expect(shield.get_current_shield() == 1, "crossing duration from near-full restores +1")
	_expect(is_equal_approx(shield.get_charge_progress(), 0.0), "near-duration restore clears charge")

	_test_graze_charge(shield)

	shield.queue_free()
	await process_frame
	var defaults := ShieldComponent.new()
	_expect(is_equal_approx(defaults.regen_charge_duration, 120.0), "auto charge defaults to 120 s per point")
	defaults.free()
	if failures.is_empty():
		print("shield regen test: PASS")
		quit()
		return
	for failure in failures:
		printerr(failure)
	print("shield regen test: FAIL (%d)" % failures.size())
	quit(1)


## Graze charge: 1/30 per graze, ignores speed multipliers, shares the hit reset.
func _test_graze_charge(shield: ShieldComponent) -> void:
	shield.absorb_damage(1)
	shield.set_process(false)
	shield.set_charge_speed_multiplier(2.0)
	shield.set_rule_charge_speed_multiplier(0.5)
	shield.set_charge_speed_multiplier(4.0)
	_expect(shield.add_graze_charge(1.0 / 30.0), "graze charges below max")
	_expect(is_equal_approx(shield.get_charge_progress(), 1.0 / 30.0), "graze adds 1/30 regardless of multipliers")
	shield.notify_hit()
	_expect(is_equal_approx(shield.get_charge_progress(), 0.0), "a hit clears graze charge too")
	for i in 29:
		shield.add_graze_charge(1.0 / 30.0)
	_expect(shield.get_current_shield() == 0, "29 grazes do not restore yet")
	shield.add_graze_charge(1.0 / 30.0)
	_expect(shield.get_current_shield() == 1, "30 grazes restore one point")
	_expect(is_equal_approx(shield.get_charge_progress(), 0.0), "graze restore clears the charge")
	_expect(not shield.add_graze_charge(1.0 / 30.0), "graze does nothing at full shield")
	shield.set_charge_speed_multiplier(1.0)
	shield.set_rule_charge_speed_multiplier(1.0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
