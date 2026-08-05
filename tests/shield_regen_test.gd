extends SceneTree

## 실드 충전: 깎이면 즉시 게이지, 풀이면 +1, 피격 시 리셋.

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

	shield.queue_free()
	await process_frame
	if failures.is_empty():
		print("shield regen test: PASS")
		quit()
		return
	for failure in failures:
		printerr(failure)
	print("shield regen test: FAIL (%d)" % failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
