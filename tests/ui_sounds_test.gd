extends SceneTree

## 효과음 연결: 버튼 누름 → accept(메타로 back·카드 선택·무음), 방향키·마우스로 생긴
## 포커스 이동만 focus(카드는 card_focus), 화면이 여는 grab_focus는 무음,
## 실드 피격·파괴·충전 회복음. 규칙: docs/design/scene-flow.md「UI 효과음」 ·
## docs/design/player.md「피격 연출」.

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSettings.instance.save_enabled = false
	await process_frame
	var hub := UiSounds.instance
	_expect(hub != null, "UiSoundHub autoload is running")
	if hub != null:
		await _test_buttons(hub)
		await _test_focus(hub)
		_test_sound_table()
	await _test_shield_sounds()
	if failures.is_empty():
		print("ui_sounds_test: PASS")
		quit()
		return
	for failure in failures:
		printerr("ui_sounds_test: %s" % failure)
	print("ui_sounds_test: FAIL (%d)" % failures.size())
	quit(1)


func _test_buttons(hub: UiSounds) -> void:
	var button := Button.new()
	root.add_child(button)
	hub.last_played = &""
	button.pressed.emit()
	_expect(hub.last_played == &"accept", "a plain button press plays accept")
	await process_frame
	button.set_meta(UiSounds.PRESS_META, &"back")
	button.pressed.emit()
	_expect(hub.last_played == &"back", "a back-tagged button plays back")
	await process_frame
	hub.last_played = &""
	button.set_meta(UiSounds.PRESS_META, &"")
	button.pressed.emit()
	_expect(hub.last_played == &"", "an empty meta silences the press")
	button.queue_free()
	await process_frame


func _test_focus(hub: UiSounds) -> void:
	var a := Button.new()
	var b := Button.new()
	var card := Button.new()
	card.set_meta(UiSounds.FOCUS_META, &"augment_card_focus")
	for control in [a, b, card]:
		root.add_child(control)
	# Let earlier input-frame stamps age out.
	for i in 3:
		await process_frame
	hub.last_played = &""
	a.grab_focus()
	_expect(hub.last_played == &"", "focus grabbed by a screen opening is silent")
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	hub._input(down)
	b.grab_focus()
	_expect(hub.last_played == &"focus", "focus moved by a direction key plays focus")
	await process_frame
	hub._input(down)
	card.grab_focus()
	_expect(hub.last_played == &"augment_card_focus", "augment cards use their own focus sound")
	for control in [a, b, card]:
		control.queue_free()
	await process_frame


func _test_sound_table() -> void:
	for id: StringName in UiSounds.SOUNDS:
		var entry: Array = UiSounds.SOUNDS[id]
		_expect(entry[0] is AudioStream and (entry[0] as AudioStream).get_length() > 0.0, "%s has a playable stream" % id)


func _test_shield_sounds() -> void:
	var world := Node2D.new()
	world.add_to_group("gameplay_world")
	root.add_child(world)
	var registry := PlayerAugmentRegistry.new()
	world.add_child(registry)
	var ship := (load("res://player_ship/ship.tscn") as PackedScene).instantiate() as Node2D
	ship.set("augment_registry", registry)
	ship.position = Vector2(200, 300)
	world.add_child(ship)
	ship.get_node("PlayerWeaponLoadout").process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var feedback := ship.get_node("PlayerHitFeedback") as PlayerHitFeedback
	var hurt := ship.get_node("HurtComponent") as HurtComponent
	var shield := ship.get_node("ShieldComponent") as ShieldComponent
	var hitbox := HitboxComponent.new()
	hitbox.damage = 1
	world.add_child(hitbox)
	hitbox.global_position = ship.global_position + Vector2(20, 0)
	hurt.hurtbox_component.hurt.emit(hitbox)
	_expect(feedback.last_sound == feedback.hit_sound, "a survivable hit plays the shield hit sound")
	hurt.end_invincibility()
	hurt.hurtbox_component.hurt.emit(hitbox)
	_expect(feedback.last_sound == feedback.break_sound, "the shield-breaking hit plays the break sound")
	feedback.last_sound = null
	shield.set_process(false)
	for i in 30:
		shield.add_graze_charge(1.0 / 30.0)
	_expect(shield.get_current_shield() == 1, "30 grazes restore a point")
	_expect(feedback.last_sound == feedback.recharge_sound, "a recharged point plays the restore sound")
	feedback.last_sound = null
	shield.add_shield(1)
	_expect(feedback.last_sound == null, "a facility max-shield bonus does not play the restore sound")
	var graze := ship.get_node("GrazeComponent") as GrazeComponent
	_expect(graze.tick_sound != null and graze.tick_volume_db <= -12.0, "graze tick is set and quiet")
	world.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
