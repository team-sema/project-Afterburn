extends Node2D
const Playfield := preload("res://menus/playfield_layout.gd")
signal health_changed(current: int, maximum: int)
signal section_changed(title: String)
signal destruction_started
signal destruction_finished
signal destruction_pulse(strength: float)
const Part = preload("res://labs/bosses/carrier/carrier_part.gd")
const Craft = preload("res://labs/bosses/carrier/carrier_craft.gd")
const TITLES := ["01 / AFT DEFENSE", "02 / FLIGHT DECK", "03 / COMMAND BRIDGE"]
const FIGHTER_CAP := 6
## Side launch hatches (hull-local y per destination phase) that release the
## transit raiders, so they visibly leave the carrier instead of popping in.
const RAID_HATCH_Y := {1: -100.0, 2: -460.0}
const RAID_HATCH_X := 80.0
const HATCH_OPEN := 0.25
const HATCH_LAUNCH := 0.3
const HATCH_CLOSE_AT := 0.7
var world: Node2D
var target: Node2D
var parts: Array[Node2D] = []
var fighters: Array[Node2D] = []
var raiders: Array[Node2D] = []
var phase := -1
var maximum := 0
var health := 0
var transitioning := false
var transit_age := 0.0
var raiders_sent := false
var hatch_age := -1.0
var hull_speed := 0.0
var last_hull_y := 0.0
var defeated := false
var section_age := 0.0
var deck_age := 0.0
var destruction_age := 0.0
var destruction_complete := false
var wreck_origin := Vector2.ZERO
var burst_index := 0
var main_blast_fired := false
var aftershock_index := 0
var detail: Node2D

func _ready() -> void:
	position = Vector2(Playfield.CENTER.x, -170)
	var hull_visual := preload("res://labs/bosses/carrier/carrier_neon_visual.gd").make(preload("res://assets/enemies/carrier_hull.svg"), 0.5, Color(1.0,0.08,0.26))
	hull_visual.position.y = -350
	hull_visual.get_node("Core").self_modulate = Color(0.35,0.12,0.2,0.8)
	hull_visual.get_node("WideGlow").self_modulate.a = 0.08
	hull_visual.get_node("TightGlow").self_modulate.a = 0.18
	add_child(hull_visual)
	var edges := preload("res://labs/bosses/carrier/carrier_neon_visual.gd").make(preload("res://assets/enemies/carrier_hull_edges.svg"), 0.5, Color(1.0,0.1,0.28))
	edges.position.y = -350
	edges.get_node("Core").self_modulate = Color(0.68,0.4,0.5,0.8)
	edges.get_node("WideGlow").self_modulate.a = 0.12
	add_child(edges)
	# Lights, windows and markings sit above the hull mask and below the parts.
	detail = Node2D.new()
	detail.draw.connect(_draw_hull_detail)
	add_child(detail)
	for i in 6:
		var turret := _add_part(Part.TURRET, 0, 80, Vector2(-58 if i % 2 == 0 else 58, 10 + (i / 2) * 52))
		turret.pattern_index = i / 2
	for i in 2:
		var engine := _add_part(Part.ENGINE, 0, 60, Vector2(-22 if i == 0 else 22, 150), false)
		engine.plume_clock = 1.5 + i * 3.5
	for i in 2:
		var hangar := _add_part(Part.HANGAR, 1, 240, Vector2(-49 if i == 0 else 49, -285))
		hangar.launch_clock = 2.0 + i * 1.2
		hangar.launch_requested.connect(_launch_fighter.bind(hangar))
	for i in 4:
		# Escorts sit on the outrigger connectors, clear of the hangar footprint.
		_add_part(Part.ESCORT, 1, 40, Vector2(-104 if i % 2 == 0 else 104, -348 + (i / 2) * 136))
	var bridge := _add_part(Part.BRIDGE, 2, 800, Vector2(0, -630))
	bridge.stage_changed.connect(_on_bridge_stage)
	health = maximum
	advance_section()

func _add_part(mode: int, section: int, hp: int, mount: Vector2, required := true) -> Node2D:
	var part := Part.new()
	part.mode = mode
	part.section = section
	part.maximum = hp
	part.required = required
	part.position = mount
	part.firing_side = -1.0 if mount.x < 0 else 1.0
	part.world = world
	part.target = target
	# Optional targets (stern engines) never count toward the shared bar.
	if required:
		maximum += hp
		part.damaged.connect(_on_damage)
	part.destroyed.connect(_on_part_destroyed)
	add_child(part)
	parts.append(part)
	return part

func section_maximum(section: int) -> int:
	var total := 0
	for part in parts:
		if part.required and part.section == section: total += part.maximum
	return total

func _on_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	health_changed.emit(health, maximum)

func _on_part_destroyed() -> void:
	if transitioning or defeated: return
	for part in parts:
		if part.required and part.section == phase and part.health > 0: return
	advance_section.call_deferred()

func _on_bridge_stage(stage: int) -> void:
	if defeated: return
	section_changed.emit(TITLES[2] + (" · OVERDRIVE" if stage == 1 else " · LAST STAND"))
	destruction_pulse.emit(1.0 if stage == 1 else 1.4)

func advance_section() -> void:
	if transitioning or defeated: return
	transitioning = true
	for part in parts: part.set_active(false)
	clear_danger()
	phase += 1
	if phase >= 3:
		defeated = true
		wreck_origin = position
		section_changed.emit("CRITICAL / HULL COLLAPSE")
		destruction_started.emit()
		destruction_pulse.emit(1.8)
		return
	transit_age = 0
	raiders_sent = false
	hatch_age = -1.0
	section_changed.emit(("WARNING / CARRIER " if phase == 0 else "APPROACH / ") + TITLES[phase])
	var movement := create_tween()
	# Physics-timed so hull_speed (read in _physics_process) sees every step.
	movement.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	movement.tween_property(self, "position:y", 30.0 + phase * 360.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Next-section hardware unfolds while the hull slides into range.
	for part in parts:
		if part.section == phase and part.health > 0:
			var unfold := part.create_tween()
			unfold.tween_interval(1.2)
			unfold.tween_property(part, "deploy", 1.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await movement.finished
	transitioning = false
	section_age = 0
	for i in parts.size():
		if parts[i].section == phase:
			parts[i].cooldown = 0.5 + (i * 0.55 if phase == 0 else (i % 4) * 0.4)
			parts[i].set_active(true)
	section_changed.emit(TITLES[phase])

func clear_danger() -> void:
	for craft in fighters + raiders:
		if is_instance_valid(craft):
			craft.set_active(false)
			craft.queue_free()
	fighters.clear()
	raiders.clear()
	EnemyBullets.cancel_all(world, EnemyBullets.get_all(world), EnemyBullets.REASON_BOSS)

func _physics_process(delta: float) -> void:
	deck_age += delta
	if delta > 0: hull_speed = (position.y - last_hull_y) / delta
	last_hull_y = position.y
	queue_redraw()
	detail.queue_redraw()
	if defeated:
		_process_destruction(delta)
		return
	if transitioning:
		transit_age += delta
		# Transit raiders keep the section change from becoming dead time. They
		# launch from side hatches once those hatches have scrolled on screen.
		if RAID_HATCH_Y.has(phase):
			if hatch_age < 0 and to_global(Vector2(0, RAID_HATCH_Y[phase])).y >= 24.0:
				hatch_age = 0.0
			elif hatch_age >= 0:
				hatch_age += delta
				if not raiders_sent and hatch_age >= HATCH_LAUNCH:
					raiders_sent = true
					for side in [-1, 1]: _spawn_raider(side)
		return
	section_age += delta
	if phase == 1:
		for part in parts:
			if part.mode == Part.ESCORT: part.fire_permission = fmod(section_age, 6.0) >= 3.0

func _spawn_craft(kind: int, at: Vector2, side: float) -> Node2D:
	var craft := Craft.new()
	craft.kind = kind
	craft.maximum = 20 if kind == Craft.Kind.FIGHTER else 10
	craft.world = world
	craft.target = target
	craft.firing_side = side
	craft.position = at
	craft.active = true
	craft.destroyed.connect(craft.queue_free)
	world.add_child(craft)
	return craft

func _spawn_raider(side: float) -> void:
	raiders = raiders.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())
	var hatch := Vector2(side * RAID_HATCH_X, RAID_HATCH_Y.get(phase, -100.0))
	var raider := _spawn_craft(Craft.Kind.RAIDER, world.to_local(to_global(hatch)), side)
	# Leave the hatch at the hull's own speed, then pull away.
	raider.launch_speed = maxf(hull_speed, 0.0)
	raiders.append(raider)

## 0..1 opening of the active side hatch pair.
func hatch_opening() -> float:
	if hatch_age < 0: return 0.0
	if hatch_age < HATCH_CLOSE_AT: return clampf(hatch_age / HATCH_OPEN, 0.0, 1.0)
	return clampf(1.0 - (hatch_age - HATCH_CLOSE_AT) / HATCH_OPEN, 0.0, 1.0)

func _launch_fighter(slot: int, hangar: Node2D) -> void:
	if transitioning or defeated or phase != 1 or not hangar.active: return
	fighters = fighters.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())
	if fighters.size() >= FIGHTER_CAP: return
	var kind := Craft.Kind.STRIKER if hangar.sortie_kind == 1 else Craft.Kind.FIGHTER
	# Aircraft leave from the lift platform inside the bay.
	var at := world.to_local(hangar.global_position + Vector2(0, 4))
	if kind == Craft.Kind.STRIKER:
		# Strikers leave from alternating catapult rails beside the hangar.
		at.x += (slot - 1) * 14
	var craft := _spawn_craft(kind, at, hangar.firing_side)
	craft.formation_slot = slot
	hangar.launch_flash = 0.5
	fighters.append(craft)

func _sink_burst(offset: Vector2, blast_radius: float) -> void:
	preload("res://labs/bosses/carrier/carrier_destruction_effect.gd").spawn(world, to_global(offset), blast_radius, true)
	destruction_pulse.emit(0.6 if blast_radius < 100 else 2.2)

func _process_destruction(delta: float) -> void:
	if destruction_complete: return
	destruction_age += delta
	while burst_index < 18 and destruction_age >= 0.45 + burst_index * 0.22:
		var progress := float(burst_index) / 17
		var offset := Vector2((-1 if burst_index % 2 == 0 else 1) * (48 + 45 * sin(progress * PI)), lerpf(-660,70,progress))
		_sink_burst(offset, 36.0 + (burst_index % 4) * 10)
		burst_index += 1
	if destruction_age >= 4.3 and not main_blast_fired:
		main_blast_fired = true
		section_changed.emit("CARRIER / BREAKING APART")
		_sink_burst(Vector2(0,-320),150)
	while aftershock_index < 3 and destruction_age >= 5.0 + aftershock_index * 0.55:
		_sink_burst(Vector2(-55 if aftershock_index % 2 == 0 else 55,-540+aftershock_index*200),70)
		aftershock_index += 1
	var sinking := smoothstep(2.6,8.2,destruction_age)
	position = wreck_origin + Vector2(-45,155) * sinking
	rotation = -0.12 * sinking
	scale = Vector2.ONE * lerpf(1.0,0.72,sinking)
	var fade := smoothstep(5.2,8.2,destruction_age)
	modulate = Color.WHITE.lerp(Color(0.16,0.13,0.23,0),fade)
	if destruction_age >= 8.2:
		destruction_complete = true
		visible = false
		section_changed.emit("CARRIER DESTROYED")
		destruction_finished.emit()

func _hull_edge(y: float) -> float:
	if y < -560: return lerpf(165, 198, inverse_lerp(-680, -560, y))
	return lerpf(198, 180, inverse_lerp(-560, 75, y))

func _draw_hull_detail() -> void:
	var dying := defeated
	# Running lights: slow alternating blink, fast bow-ward chase in transit.
	var lights := [-640, -520, -400, -280, -160, -40, 60]
	for side in [-1, 1]:
		for i in lights.size():
			var y: float = lights[i]
			var point: Vector2 = Vector2(side * (_hull_edge(y) - 7), y)
			var beat := fmod(deck_age * (2.5 if transitioning else 0.9) + (lights.size() - i) * 0.12 + (0.5 if side > 0 else 0.0), 1.0)
			var lit := beat < 0.16 and not dying
			var tint := Color(2.2,0.35,0.45) if side < 0 else Color(1.6,1.4,1.6)
			detail.draw_circle(point, 1.6 if lit else 1.0, tint if lit else Color(0.35,0.16,0.24))
			if lit: detail.draw_circle(point, 4.0, Color(tint, 0.18))
	# Port windows along the side armor give the hull its scale.
	for side in [-1, 1]:
		for i in 26:
			var y := -500.0 + i * 20.0
			var x: float = side * (_hull_edge(y) - 24)
			var lit := hash(i * 7 + side) % 3 != 0 and not dying
			detail.draw_line(Vector2(x, y), Vector2(x, y + 5), Color(0.95,0.5,0.4,0.4) if lit else Color(0.3,0.15,0.22,0.5), 1.0)
	# Hatches and service plates between the combat sections.
	for hatch in [Rect2(-26,-140,14,10), Rect2(12,-140,14,10), Rect2(-120,-110,16,22), Rect2(104,-110,16,22), Rect2(-122,-470,14,26), Rect2(108,-470,14,26), Rect2(-24,-470,48,14), Rect2(-120,-700,14,20), Rect2(106,-700,14,20)]:
		detail.draw_rect(hatch, Color(0.45,0.2,0.3,0.55), false, 1.0)
		detail.draw_line(hatch.position + Vector2(2, hatch.size.y * 0.5), hatch.end - Vector2(2, hatch.size.y * 0.5), Color(0.35,0.16,0.24,0.5), 1.0)
	# Side launch hatches for the transit raiders.
	for key in RAID_HATCH_Y:
		var y: float = RAID_HATCH_Y[key]
		var opening := hatch_opening() if transitioning and key == phase and not dying else 0.0
		for side in [-1.0, 1.0]:
			var center := Vector2(side * RAID_HATCH_X, y)
			var bay := Rect2(center - Vector2(7, 9), Vector2(14, 18))
			detail.draw_rect(bay.grow(2), Color(0.04, 0.02, 0.05))
			if opening > 0:
				detail.draw_rect(bay, Color(0.9, 0.35, 0.2, 0.25 + 0.35 * opening))
				detail.draw_circle(center + Vector2(0, -12), 1.5, Color(2.2, 1.2, 0.3))
			var leaf := 7.0 * (1.0 - opening)
			for leaf_side in [-1.0, 1.0]:
				if leaf < 0.5: continue
				var outer: float = center.x + leaf_side * 7.0
				var door := Rect2(minf(outer, outer - leaf_side * leaf), bay.position.y, leaf, bay.size.y)
				detail.draw_rect(door, Color(0.14, 0.065, 0.1))
				detail.draw_rect(door, Color(0.55, 0.24, 0.34), false, 1.0)
			detail.draw_rect(bay.grow(2), Color(0.45, 0.2, 0.3, 0.7), false, 1.0)
	var font := ThemeDB.fallback_font
	detail.draw_string(font, Vector2(-60, -64), "07", HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color(0.6,0.24,0.34,0.35))
	detail.draw_string(font, Vector2(-60, -432), "CV-07", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.6,0.24,0.34,0.4))
	if transitioning and not dying:
		# Centre-line chase toward the next section while the hull advances.
		for i in 50:
			var y := 140.0 - i * 20.0
			if posmod(i - int(deck_age * 14.0), 6) == 0:
				detail.draw_circle(Vector2(0, y), 1.5, Color(2.0,0.4,0.55))

func _draw() -> void:
	# Keep the deck dark so the weapon cores and projectiles stay in front.
	var hull := PackedVector2Array([Vector2(0,-860),Vector2(165,-680),Vector2(198,-560),Vector2(180,75),Vector2(145,145),Vector2(-145,145),Vector2(-180,75),Vector2(-198,-560),Vector2(-165,-680)])
	draw_colored_polygon(hull, Color("0d0915"))
	# Inset flight deck and launch rails belong to the moving hull, not the HUD.
	var flight_deck := PackedVector2Array([Vector2(-78,-359),Vector2(78,-359),Vector2(80,-188),Vector2(59,-156),Vector2(-59,-156),Vector2(-80,-188)])
	draw_colored_polygon(flight_deck, Color("170e20"))
	draw_polyline(PackedVector2Array([Vector2(-78,-359),Vector2(-80,-188),Vector2(-59,-156),Vector2(59,-156),Vector2(80,-188),Vector2(78,-359)]),Color("653146"),1.5,true)
	for side in [-1,1]:
		for i in 12:
			var y := -344.0 + i * 14
			var lit := phase == 1 and not transitioning and not defeated and posmod(i-int(deck_age*5),4)==0
			draw_line(Vector2(side*8,y),Vector2(side*8,y+6),Color(1.4,0.5,0.22) if lit else Color("573045"),2.0)
		for y in [-348,-212]:
			draw_line(Vector2(side*80,y),Vector2(side*88,y),Color("5c3046"),2.0)
	for i in 4:
		var y := -660.0 + i * 18
		draw_polyline(PackedVector2Array([Vector2(-52,y),Vector2(-32,y+8),Vector2(32,y+8),Vector2(52,y)]),Color("683249"),1.0,true)
