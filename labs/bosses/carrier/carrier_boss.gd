extends Node2D
signal health_changed(current: int, maximum: int)
signal section_changed(title: String)
signal destruction_started
signal destruction_finished
signal destruction_pulse(strength: float)
const Part = preload("res://labs/bosses/carrier/carrier_part.gd")
const TITLES := ["01 / AFT DEFENSE", "02 / FLIGHT DECK", "03 / COMMAND BRIDGE"]
var world: Node2D
var target: Node2D
var parts: Array[Node2D] = []
var fighters: Array[Node2D] = []
var phase := -1
var health := 800
var transitioning := false
var defeated := false
var section_age := 0.0
var deck_age := 0.0
var destruction_age := 0.0
var destruction_complete := false
var wreck_origin := Vector2.ZERO
var burst_index := 0
var main_blast_fired := false
var aftershock_index := 0

func _ready() -> void:
	position = Vector2(120, -170)
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
	for i in 6:
		var turret := _add_part(0, 0, 40, Vector2(-58 if i % 2 == 0 else 58, 10 + (i / 2) * 52))
		turret.pattern_index = i / 2
	for i in 2:
		var hangar := _add_part(1, 1, 120, Vector2(-49 if i == 0 else 49, -285))
		hangar.launch_clock = 2.0 + i * 1.2
		hangar.launch_requested.connect(_launch_fighter.bind(hangar))
	for i in 4:
		_add_part(4, 1, 20, Vector2(-89 if i % 2 == 0 else 89, -334 + (i / 2) * 112))
	_add_part(2, 2, 240, Vector2(0, -630))
	advance_section()

func _add_part(mode: int, section: int, hp: int, mount: Vector2) -> Node2D:
	var part := Part.new()
	part.mode = mode
	part.section = section
	part.maximum = hp
	part.position = mount
	part.firing_side = -1.0 if mount.x < 0 else 1.0
	part.world = world
	part.target = target
	part.damaged.connect(_on_damage)
	part.destroyed.connect(_on_part_destroyed)
	add_child(part)
	parts.append(part)
	return part

func _on_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	health_changed.emit(health, 800)

func _on_part_destroyed() -> void:
	if transitioning or defeated: return
	for part in parts:
		if part.section == phase and part.health > 0: return
	advance_section.call_deferred()

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
	section_changed.emit("APPROACH / " + TITLES[phase])
	var movement := create_tween()
	movement.tween_property(self, "position:y", 30.0 + phase * 360.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await movement.finished
	transitioning = false
	section_age = 0
	for i in parts.size():
		if parts[i].section == phase:
			parts[i].cooldown = 0.5 + (i * 0.55 if phase == 0 else (i % 4) * 0.4)
			parts[i].set_active(true)
	section_changed.emit(TITLES[phase])

func clear_danger() -> void:
	for fighter in fighters:
		if is_instance_valid(fighter):
			fighter.set_active(false)
			fighter.queue_free()
	fighters.clear()
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if world.is_ancestor_of(projectile): projectile.queue_free()

func _physics_process(delta: float) -> void:
	deck_age += delta
	queue_redraw()
	if defeated:
		_process_destruction(delta)
		return
	if transitioning: return
	section_age += delta
	if phase == 1:
		for part in parts:
			if part.mode == 4: part.fire_permission = fmod(section_age, 6.0) >= 3.0

func _launch_fighter(slot: int, hangar: Node2D) -> void:
	if transitioning or defeated or phase != 1 or not hangar.active: return
	fighters = fighters.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())
	if fighters.size() >= 6: return
	var fighter := Part.new()
	fighter.mode = 3
	fighter.maximum = 20
	fighter.world = world
	fighter.target = target
	fighter.formation_slot = slot
	fighter.firing_side = hangar.firing_side
	fighter.position = world.to_local(hangar.global_position + Vector2(0, 12))
	fighter.active = true
	hangar.launch_flash = 0.5
	fighter.destroyed.connect(fighter.queue_free)
	world.add_child(fighter)
	fighters.append(fighter)

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
			draw_line(Vector2(side*80,y),Vector2(side*105,y),Color("5c3046"),2.0)
	for i in 4:
		var y := -660.0 + i * 18
		draw_polyline(PackedVector2Array([Vector2(-52,y),Vector2(-32,y+8),Vector2(32,y+8),Vector2(52,y)]),Color("683249"),1.0,true)
