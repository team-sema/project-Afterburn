extends SceneTree

## 그레이즈 실드 충전: 피격점 반경 +10px 안에 적탄이 있는 동안 0.1초마다 1회,
## 1회 = 실드 1/30칸 · 10점. 탄 수와 무관, 무적·실드 최대·무판정 탄·범위 밖 예외,
## 레거시 탄, 압축 코어 반경, 피격 리셋, HUD 충전 막대 발광.
## 규칙: docs/design/player.md「그레이즈」.

const ROUND := preload("res://resources/projectiles/round.tres")
var _game_stats: GameStats = preload("res://game_stats.tres")

var failures: PackedStringArray = []
var _world: Node2D
var _ship: Node2D
var _graze: GrazeComponent
var _shield: ShieldComponent
var _hurt: HurtComponent
var _bullets: Array[Node] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSettings.instance.save_enabled = false
	var original_score: int = _game_stats.score
	_world = Node2D.new()
	_world.add_to_group("gameplay_world")
	root.add_child(_world)
	var registry := PlayerAugmentRegistry.new()
	_world.add_child(registry)
	_ship = (load("res://player_ship/ship.tscn") as PackedScene).instantiate() as Node2D
	_ship.set("augment_registry", registry)
	_ship.position = Vector2(200, 300)
	_world.add_child(_ship)
	_graze = _ship.get_node("GrazeComponent") as GrazeComponent
	_shield = _ship.get_node("ShieldComponent") as ShieldComponent
	_hurt = _ship.get_node("HurtComponent") as HurtComponent
	_ship.get_node("PlayerWeaponLoadout").process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)

	_expect(is_equal_approx(_graze.get_radius(), 13.0), "graze ring is hit point 3px + 10px")
	_expect(_shield.get_current_shield() == 2, "run starts at full shield")
	_shield.absorb_damage(1)
	# Auto charge is 120 s per point; keep it out of the counts below.
	_shield.set_process(false)

	await _test_single_bullet()
	await _test_out_of_range()
	await _test_bullet_count_ignored()
	await _test_intangible()
	await _test_invincible()
	await _test_hit_reset()
	await _test_full_shield()
	await _test_legacy_bullet()
	await _test_compressed_core()
	await _test_hud_glow()

	_world.queue_free()
	_game_stats.score = original_score
	await process_frame
	if failures.is_empty():
		print("graze_shield_charge_test: PASS")
		quit()
		return
	for failure in failures:
		printerr("graze_shield_charge_test: %s" % failure)
	print("graze_shield_charge_test: FAIL (%d)" % failures.size())
	quit(1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _spawn(offset: Vector2, behavior := BulletBehavior.new().wait(30.0)) -> FoundationBullet:
	var shot := BarrageShot.new()
	shot.kind = BarrageShot.Kind.BULLET
	shot.behavior = behavior
	shot.lifetime = 30.0
	shot.appearance = ROUND
	var bullet := shot.spawn(_world, _graze.get_center() + offset, Vector2.DOWN, 0.0) as FoundationBullet
	_bullets.append(bullet)
	return bullet


func _clear_bullets() -> void:
	for bullet in _bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	_bullets.clear()
	await _frames(2)
	_graze._accumulated = 0.0


func _test_single_bullet() -> void:
	var count := _graze.get_graze_count()
	var score: int = _game_stats.score
	var progress := _shield.get_charge_progress()
	# Round bullet radius 3: 11px away grazes (≤ 13 + 3) without hitting (> 3 + 3).
	_spawn(Vector2(11, 0))
	await _frames(1)
	await _frames(30) # 0.5 s in range
	var grazes := _graze.get_graze_count() - count
	_expect(grazes == 5, "0.5 s next to one bullet grazes 5 times (got %d)" % grazes)
	_expect(_game_stats.score - score == grazes * GrazeComponent.SCORE_PER_GRAZE, "each graze scores 10")
	_expect(is_equal_approx(_shield.get_charge_progress() - progress, grazes / 30.0), "each graze charges 1/30 of a point")
	_expect(_shield.get_current_shield() == 1, "the grazed bullet did not hit")
	await _clear_bullets()


func _test_out_of_range() -> void:
	var count := _graze.get_graze_count()
	_spawn(Vector2(17, 0)) # 17 > 13 + 3
	await _frames(20)
	_expect(_graze.get_graze_count() == count, "a bullet outside the ring does not graze")
	await _clear_bullets()


func _test_bullet_count_ignored() -> void:
	var count := _graze.get_graze_count()
	_spawn(Vector2(11, 0))
	_spawn(Vector2(-11, 0))
	_spawn(Vector2(0, 11))
	await _frames(1)
	await _frames(30)
	var grazes := _graze.get_graze_count() - count
	_expect(grazes == 5, "three bullets in range still graze 5 times in 0.5 s (got %d)" % grazes)
	await _clear_bullets()


func _test_intangible() -> void:
	var count := _graze.get_graze_count()
	_spawn(Vector2(11, 0), BulletBehavior.new().intangible().wait(30.0))
	await _frames(20)
	_expect(_graze.get_graze_count() == count, "an intangible bullet does not graze")
	await _clear_bullets()


func _test_invincible() -> void:
	var count := _graze.get_graze_count()
	_hurt.start_invincibility(1.0)
	_spawn(Vector2(11, 0))
	await _frames(20)
	_expect(_graze.get_graze_count() == count, "no graze during invincibility")
	_expect(is_equal_approx(_graze._accumulated, 0.0), "invincibility pauses the graze timer")
	_hurt.end_invincibility()
	await _clear_bullets()


func _test_hit_reset() -> void:
	_spawn(Vector2(11, 0))
	await _frames(13)
	_expect(_shield.get_charge_progress() > 0.0, "grazing builds charge")
	_shield.notify_hit()
	_expect(is_equal_approx(_shield.get_charge_progress(), 0.0), "a hit clears graze-built charge")
	await _clear_bullets()


func _test_full_shield() -> void:
	_shield.restore_shield(1)
	_shield.set_process(false)
	var count := _graze.get_graze_count()
	var score: int = _game_stats.score
	var charged: Array[bool] = []
	var on_grazed := func(_position: Vector2, did_charge: bool) -> void: charged.append(did_charge)
	_graze.grazed.connect(on_grazed)
	_spawn(Vector2(11, 0))
	await _frames(1)
	await _frames(12)
	var grazes := _graze.get_graze_count() - count
	_expect(grazes == 2, "full shield still grazes (got %d)" % grazes)
	_expect(_game_stats.score - score == grazes * GrazeComponent.SCORE_PER_GRAZE, "full shield grazes still score")
	_expect(not charged.is_empty() and not charged.has(true), "full shield grazes charge nothing")
	_expect(_shield.get_current_shield() == 2, "full shield stays at max")
	_graze.grazed.disconnect(on_grazed)
	await _clear_bullets()
	_shield.absorb_damage(1)
	_shield.set_process(false)


func _test_legacy_bullet() -> void:
	var count := _graze.get_graze_count()
	var legacy := (load("res://projectiles/base_enemy_projectile.tscn") as PackedScene).instantiate() as Node2D
	(legacy.get_node("MoveComponent") as MoveComponent).velocity = Vector2.ZERO
	_world.add_child(legacy)
	legacy.global_position = _graze.get_center() + Vector2(11, 0)
	_bullets.append(legacy)
	await _frames(3)
	await _frames(30)
	var grazes := _graze.get_graze_count() - count
	_expect(grazes >= 4 and grazes <= 5, "a legacy bullet grazes too (got %d)" % grazes)
	_expect(is_instance_valid(legacy) and _shield.get_current_shield() == 1, "the legacy bullet did not hit")
	await _clear_bullets()


func _test_compressed_core() -> void:
	var hit_point := _ship.get_node("PlayerHitPoint") as PlayerHitPoint
	hit_point.radius = 2.0
	_expect(is_equal_approx(_graze.get_radius(), 12.0), "compressed core shrinks the ring to 12px")
	var count := _graze.get_graze_count()
	_spawn(Vector2(15.5, 0)) # inside 13 + 3, outside 12 + 3
	await _frames(20)
	_expect(_graze.get_graze_count() == count, "the shrunk ring misses a bullet at 15.5px")
	hit_point.radius = PlayerHitPoint.BASE_RADIUS
	await _clear_bullets()


func _test_hud_glow() -> void:
	var hud := (load("res://menus/ship_status_hud.gd") as GDScript).new() as ShipStatusHud
	var bar := ProgressBar.new()
	bar.name = "ShieldChargeBar"
	bar.unique_name_in_owner = true
	for node_name in ["ShieldLabel", "ShieldBar"]:
		var child: Control = Label.new() if node_name == "ShieldLabel" else ProgressBar.new()
		child.name = node_name
		hud.add_child(child)
		child.owner = hud
		child.unique_name_in_owner = true
	hud.add_child(bar)
	bar.owner = hud
	hud.ship = _ship
	root.add_child(hud)
	await process_frame
	await process_frame
	_graze.grazed.emit(Vector2.ZERO, false)
	_expect(not hud.is_graze_glowing(), "a non-charging graze leaves the bar alone")
	_graze.grazed.emit(Vector2.ZERO, true)
	_expect(hud.is_graze_glowing() and bar.self_modulate.r > 1.5, "a charging graze brightens the charge bar")
	hud._process(0.2)
	_expect(not hud.is_graze_glowing() and bar.self_modulate == Color.WHITE, "the glow fades after 0.15 s")
	hud.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
