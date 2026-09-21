extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var world := Node2D.new()
	root.add_child(world)

	var barrier := load("res://player_ship/weapons/orbital_barrier_weapon_system.tscn").instantiate() as OrbitalBarrierWeaponSystem
	barrier.segment_integrity = 1
	barrier.respawn_delay = 0.2
	world.add_child(barrier)
	await process_frame

	var segment := barrier.get_node("OrbitRoot").get_child(0) as Node2D
	var hurtbox := segment.get_node("HurtboxComponent") as HurtboxComponent
	var glow := segment.get_node("Glow") as CanvasItem
	if barrier.get_segment_integrity(segment) != 1:
		failures.append("segment starts at full integrity")
	if barrier.is_segment_broken(segment):
		failures.append("segment should start unbroken")

	var hit := HitboxComponent.new()
	hit.damage = 1
	hurtbox.hurt.emit(hit)
	hit.free()
	await process_frame
	if not barrier.is_segment_broken(segment):
		failures.append("one damage at integrity 1 should break the segment")
	if glow.visible:
		failures.append("broken segment visuals should hide")
	if not hurtbox.is_invincible:
		failures.append("broken segment hurtbox should be invincible")

	# Extra hits while broken must not schedule another break state.
	hit = HitboxComponent.new()
	hit.damage = 9
	hurtbox.hurt.emit(hit)
	hit.free()
	if barrier.get_segment_integrity(segment) != 0:
		failures.append("broken segment ignores further damage")

	await create_timer(0.25).timeout
	await process_frame
	if barrier.is_segment_broken(segment):
		failures.append("segment should respawn after delay")
	if barrier.get_segment_integrity(segment) != 1:
		failures.append("respawn restores full integrity")
	if not glow.visible:
		failures.append("respawned segment visuals should show")
	if hurtbox.is_invincible:
		failures.append("respawned segment hurtbox should accept hits")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("orbital_barrier_break_respawn_smoke_test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("orbital_barrier_break_respawn_smoke_test: FAIL")
		quit(1)
