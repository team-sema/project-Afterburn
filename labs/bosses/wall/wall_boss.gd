extends Node2D
## RECYCLER: the disassembly bay inside a moving fortress. The bay itself is the weapon — crusher bulkheads,
## cutter optics and the maw press — and all of it moves on commands from one small control core in the ceiling.
## Cutting the last control link ends the fight; the shutdown then exposes the core and lets it burn out.
signal health_changed(current: int, maximum: int)
signal section_changed(title: String)
signal destruction_started
signal destruction_finished
signal pulse(strength: float)

const Playfield = preload("res://menus/playfield_layout.gd")
const Neon = preload("res://labs/bosses/wall/wall_visual.gd")
const Destruction = preload("res://labs/bosses/carrier/carrier_destruction_effect.gd")
const Part = preload("res://labs/bosses/wall/wall_part.gd")
const Bulkhead = preload("res://labs/bosses/wall/wall_bulkhead.gd")
const Beam = preload("res://labs/bosses/wall/wall_beam.gd")
const Debris = preload("res://labs/bosses/wall/wall_debris.gd")
const Pattern = preload("res://patterns/wall_lab_pattern.gd")
## Structure color: armor and machinery.
const STRUCTURE := Neon.STRUCTURE
## Control-system color: optics, links, core and their warnings.
const SIGNAL := Color(1.0, 0.16, 0.2)
const MAX_HEALTH := 850
const TITLES := ["01 / CRUSHER BULKHEADS", "02 / CUTTER ARRAY", "03 / MAW PRESS"]
## 01 lunges: the extended wall is the opening. First lunge, period (sides alternate) and hold at full reach.
const LUNGE_FIRST := 2.5
const LUNGE_PERIOD := 5.0
const LUNGE_HOLD := 3.0
## 02: no laser moves while it fires. Ceiling optics track, then freeze for AIM_LOCK before the beam comes on.
const AIM_LOCK := 0.35
## 02 scan carriage: steps down its rail and fires a still bar at each stop; it only travels with the bar off.
const SCAN_STOPS := [140.0, 210.0, 280.0, 350.0]
const SCAN_MOVE := 0.3
const SCAN_WARN := 0.5
const SCAN_FIRE := 0.6
const SCAN_RETURN := 1.0
const SCAN_REST := 1.5
## Shutdown beats, in seconds after the last link is cut.
const POWER_DOWN_AT := 1.2
const CORE_REVEAL_AT := 2.0
const CORE_EXPOSED_AT := 3.2
const OVERLOAD_AT := 4.0
const SAG_AT := 4.6
const SHUTDOWN_AT := 7.6
const HALF_W := 150.0
const CEILING_LINE := 64.0
const WALL_REST := 30.0
const OPTIC_X := [-70.0, 70.0]
const LINK_X := [-72.0, 0.0, 72.0]
const RAM_X := [-100.0, 0.0, 100.0]
const PRESS_DEPTH := 70.0
enum Contraction { SQUEEZE_LR, SQUEEZE_UD, TWIST, SNAP }
enum OpticCycle { REST, AIM, FIRE }
enum Scan { REST, MOVE, WARN, FIRE, RETURN }

var world: Node2D
var target: Node2D
## Optional wall_background.gd node; the bay halts it on arrival and the kill surges it.
var background: Node
var phase := -1
var health := MAX_HEALTH
var transitioning := true
var defeated := false
var destruction_complete := false
var age := 0.0
var section_age := 0.0
# Geometry: ceiling_y = ceiling armor line, upper_y / lower_y = tooth tips of the upper / lower press.
var ceiling_y := -40.0:
	set(value):
		ceiling_y = value
		if ceiling != null: ceiling.position.y = ceiling_y
var upper_y := -40.0
var lower_y := 430.0
var _last_upper := -40.0
var _last_lower := 430.0
var upper_closing := false
var lower_closing := false
var armor_split := 0.0
## 0..1 view of the core's scanner deep in the ceiling while the armor first splits.
var glimpse := 0.0
## Bay lamp brightness; the core powers everything and the lights die with its links.
var power := 1.0
var fault_left := 0.0
var press_shake := 0.0
var press_warning := 0.0
var spark_clock := 1.0
var ceiling: Node2D
var halves: Array[Node2D] = []
var backing: Node2D
var overlay: Node2D
var ceiling_armor: HurtboxComponent
var press_top: Node2D
var press_bottom: Node2D
var press_apex: Node2D
var press_visual_top: Node2D
var press_visual_bottom: Node2D
var ram_nodes: Array[Node2D] = []
var command_overlay: Node2D
var bulkheads: Array[Node2D] = []
var optics: Array[Node2D] = []
var optic_beams: Array[Node2D] = []
var links: Array[Node2D] = []
var core: Node2D
var spit_barrage: BarragePlayer
var crush_hitbox: HitboxComponent
# 01 / CRUSHER BULKHEADS
var lunge_clock := 5.0
var lunge_side := 0
var drive_announced := false
# 02 / CUTTER ARRAY
var optic_cycle := OpticCycle.REST
var optic_clock := 0.6
var band_clock := [1.5, 4.5]
var band_state := [Scan.REST, Scan.REST]
var band_stop := [0, 0]
var band_from := [0.0, 0.0]
var jitter_left := 0.0
# 03 / MAW PRESS
var contraction_run := 0
var contraction_index := 0
var links_cut := 0
var motion: Tween
# Shutdown
var destruction_age := 0.0
var ending_step := 0
var burst_step := 0
var core_origin := Vector2.ZERO
var link_flash := 0.0
var link_alpha := 0.0


func _ready() -> void:
	# Run after the ship's own movement and screen clamp so pushes land on this frame's position.
	process_priority = 100
	for side in [-1, 1]:
		var bulkhead := Bulkhead.new()
		bulkhead.side = side
		bulkhead.world = world
		add_child(bulkhead)
		bulkhead.cover.damaged.connect(_on_damage)
		bulkhead.cover.destroyed.connect(_on_cover_breached.bind(bulkhead))
		bulkhead.optic.damaged.connect(_on_damage)
		bulkhead.optic.destroyed.connect(_on_optic_destroyed.bind(bulkhead.optic, bulkhead.beam))
		bulkhead.lunge_landed.connect(func(): pulse.emit(0.9))
		bulkheads.append(bulkhead)
	press_bottom = _make_press(false)
	press_top = _make_press(true)
	press_apex = Node2D.new()
	press_apex.position.y = 2.0
	press_top.add_child(press_apex)
	for x in LINK_X:
		var link := Part.new()
		link.mode = Part.Mode.LINK
		link.maximum = 90
		link.world = world
		link.visible = false
		press_top.add_child(link)
		link.damaged.connect(_on_damage)
		link.destroyed.connect(_on_link_cut.bind(link))
		links.append(link)
	ceiling = Node2D.new()
	ceiling.position.x = HALF_W
	add_child(ceiling)
	backing = Node2D.new()
	backing.draw.connect(_draw_backing)
	ceiling.add_child(backing)
	for i in OPTIC_X.size():
		var optic := Part.new()
		optic.mode = Part.Mode.OPTIC
		optic.maximum = 70
		optic.world = world
		optic.position = Vector2(OPTIC_X[i], -14)
		optic.visible = false
		ceiling.add_child(optic)
		optic.damaged.connect(_on_damage)
		var beam := Beam.new()
		beam.position = optic.position
		beam.visible = false
		ceiling.add_child(beam)
		optic.destroyed.connect(_on_optic_destroyed.bind(optic, beam))
		optics.append(optic)
		optic_beams.append(beam)
	for side in [-1, 1]:
		var half := Node2D.new()
		half.scale.x = side * -1.0
		var visual := Neon.make(preload("res://assets/enemies/wall_ceiling_half.svg"), 0.5, STRUCTURE, preload("res://assets/enemies/wall_ceiling_half_body.svg"))
		visual.position = Vector2(-75, -50)
		Neon.structure(visual, power)
		half.add_child(visual)
		ceiling.add_child(half)
		halves.append(half)
	ceiling_armor = HurtboxComponent.new()
	ceiling_armor.collision_layer = 2
	ceiling_armor.collision_mask = 0
	ceiling_armor.blocks_pierce = true
	var armor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(300, 420)
	armor_shape.shape = rectangle
	armor_shape.position.y = -210
	ceiling_armor.add_child(armor_shape)
	ceiling.add_child(ceiling_armor)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	ceiling.add_child(overlay)
	command_overlay = Node2D.new()
	command_overlay.draw.connect(_draw_command_links)
	add_child(command_overlay)
	# The control core only appears in the shutdown; it never fights.
	core = Part.new()
	core.mode = Part.Mode.CORE
	core.maximum = 1
	core.world = world
	core.position = Vector2(HALF_W, 20)
	core.visible = false
	add_child(core)
	spit_barrage = _add_barrage()
	crush_hitbox = HitboxComponent.new()
	crush_hitbox.collision_layer = 0
	crush_hitbox.collision_mask = 0
	crush_hitbox.monitoring = false
	crush_hitbox.monitorable = false
	crush_hitbox.damage = 1
	add_child(crush_hitbox)
	ceiling_y = ceiling_y
	_sync_geometry()
	_enter()


func _make_press(top: bool) -> Node2D:
	var press := Node2D.new()
	press.position = Vector2(HALF_W, upper_y if top else lower_y)
	add_child(press)
	var rams := Node2D.new()
	rams.draw.connect(_draw_rams.bind(rams, top))
	press.add_child(rams)
	ram_nodes.append(rams)
	var holder := Node2D.new()
	holder.scale.y = 1.0 if top else -1.0
	press.add_child(holder)
	var visual := Neon.make(preload("res://assets/enemies/wall_press.svg"), 0.5, STRUCTURE, preload("res://assets/enemies/wall_press_body.svg"))
	visual.position.y = -PRESS_DEPTH * 0.5
	Neon.structure(visual, power)
	holder.add_child(visual)
	if top:
		press_visual_top = visual
		# The upper platen stops shots like the rest of the armor; links hang below it and are hit first.
		var armor := HurtboxComponent.new()
		armor.collision_layer = 2
		armor.collision_mask = 0
		armor.blocks_pierce = true
		var outline := CollisionPolygon2D.new()
		outline.polygon = PackedVector2Array([Vector2(-150, -PRESS_DEPTH), Vector2(150, -PRESS_DEPTH), Vector2(150, -22), Vector2(12, 0), Vector2(-12, 0), Vector2(-150, -22)])
		armor.add_child(outline)
		press.add_child(armor)
	else:
		press_visual_bottom = visual
	return press


func _add_barrage() -> BarragePlayer:
	var barrage := BarragePlayer.new()
	add_child(barrage)
	return barrage


func _alive() -> bool:
	return is_inside_tree() and not defeated


## Wait on a tween bound to this node: it pauses with the Lab and dies with the boss on restart.
func _pause_for(seconds: float) -> Signal:
	var hold := create_tween()
	hold.tween_interval(seconds)
	return hold.finished


func _press_base(x: float) -> float:
	return -10.0 - 0.16 * maxf(absf(x) - 12.0, 0.0)


# ---------------------------------------------------------------- entry

func _enter() -> void:
	section_changed.emit("INTAKE / DISASSEMBLY BAY")
	var descent := create_tween()
	descent.tween_property(self, "ceiling_y", CEILING_LINE, 2.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	descent.parallel().tween_property(self, "upper_y", CEILING_LINE, 2.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if background != null:
		# The starfield stops: the bay has closed around the ship.
		descent.parallel().tween_property(background, "speed_scale", 0.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for bulkhead in bulkheads:
		var slide := create_tween()
		slide.tween_interval(1.0)
		slide.tween_property(bulkhead, "inset", WALL_REST, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await descent.finished
	if not _alive(): return
	_begin_section(0)


func _begin_section(index: int) -> void:
	phase = index
	section_age = 0.0
	transitioning = false
	section_changed.emit(TITLES[index])
	match index:
		0:
			for bulkhead in bulkheads:
				bulkhead.breathing = true
				bulkhead.breathe_center = WALL_REST
				# Covers stay closed (out of play, shots pass) until their wall lunges.
				bulkhead.cover_window = true
				bulkhead.seal_cover()
			bulkheads[0].start_fire(1.0)
			bulkheads[1].start_fire(2.6)
			lunge_clock = LUNGE_FIRST
		1:
			for optic in optics: optic.set_active(true)
			for bulkhead in bulkheads: bulkhead.optic.set_active(true)
			optic_cycle = OpticCycle.REST
			optic_clock = 0.6
			band_clock = [1.5, 4.5]
			band_state = [Scan.REST, Scan.REST]
			band_stop = [0, 0]
		2:
			for link in links: link.set_active(true)
			contraction_index = 0
			contraction_run += 1
			press_shake = 1.2
			_contraction_loop(contraction_run)


func _advance() -> void:
	if transitioning or defeated: return
	transitioning = true
	_clear_danger()
	match phase:
		0:
			for bulkhead in bulkheads: bulkhead.cover_window = false
			_transition_to_array()
		1: _transition_to_press()
		2: _shutdown()


# ---------------------------------------------------------------- damage plumbing

func _on_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)


func _section_parts(index: int) -> Array[Node2D]:
	var result: Array[Node2D] = []
	match index:
		0:
			for bulkhead in bulkheads: result.append(bulkhead.cover)
		1:
			result.assign(optics)
			for bulkhead in bulkheads: result.append(bulkhead.optic)
		2:
			result.assign(links)
	return result


func _check_section_cleared() -> void:
	if transitioning or defeated: return
	for part in _section_parts(phase):
		if part.health > 0: return
	_advance.call_deferred()


func _clear_danger() -> void:
	spit_barrage.stop()
	for bulkhead in bulkheads:
		bulkhead.stop_fire()
		bulkhead.beam.set_state(Beam.State.OFF)
	for beam in optic_beams:
		beam.set_state(Beam.State.OFF)
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if world != null and world.is_ancestor_of(projectile): projectile.queue_free()


func _sparks(origin: Vector2, count: int) -> void:
	for i in count:
		Debris.spawn(world, origin, Debris.Kind.SPARK, randf_range(4.0, 8.0))


# ---------------------------------------------------------------- 01 / CRUSHER BULKHEADS

func _on_cover_breached(bulkhead: Node2D) -> void:
	# The cover goes and the casing with it: rams, screws and gearing are what really moves this wall.
	pulse.emit(1.0)
	bulkhead.move_to(bulkhead.inset - 22.0, 0.18, Tween.TRANS_BACK)
	var origin: Vector2 = bulkhead.cover.global_position
	for i in 6:
		Debris.spawn(world, origin + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Debris.Kind.PLATE, randf_range(4.0, 8.0))
	for i in 4:
		Debris.spawn(world, Vector2(bulkhead.face_x() + bulkhead.side * randf_range(4.0, 20.0), randf_range(120.0, 320.0)), Debris.Kind.PLATE, randf_range(5.0, 9.0))
	_sparks(origin, 10)
	if not drive_announced:
		drive_announced = true
		section_changed.emit(TITLES[0] + " — DRIVE EXPOSED")
	_check_section_cleared()


func _process_bulkheads(delta: float) -> void:
	lunge_clock -= delta
	if lunge_clock > 0.0: return
	# A breached wall drops out of the rotation: the surviving armored wall takes every beat,
	# starting each lunge as soon as it is back from the last, so its cover stays in reach.
	if bulkheads[lunge_side].casing_breached: lunge_side = 1 - lunge_side
	var bulkhead: Node2D = bulkheads[lunge_side]
	if bulkhead.is_moving(): return
	lunge_clock = LUNGE_PERIOD
	bulkhead.lunge(96.0, 0.9, LUNGE_HOLD)
	lunge_side = 1 - lunge_side


func _transition_to_array() -> void:
	# Casing gone: the bay wakes its internal defenses.
	section_changed.emit("CASING BREACH / DEFENSE ONLINE")
	pulse.emit(0.8)
	var beat := create_tween()
	beat.tween_interval(0.5)
	beat.tween_callback(_deploy_optics)
	beat.tween_interval(1.3)
	await beat.finished
	if not _alive(): return
	_begin_section(1)


func _deploy_optics() -> void:
	for bulkhead in bulkheads: bulkhead.deploy_optic(0.8)
	for i in optics.size():
		optics[i].visible = true
		var drop := create_tween()
		drop.tween_property(optics[i], "position:y", 10.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.parallel().tween_property(optic_beams[i], "position:y", 10.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 02 / CUTTER ARRAY

func _target_angle_from(origin: Vector2, limit_degrees: float) -> float:
	if not is_instance_valid(target): return 0.0
	var angle := Vector2.DOWN.angle_to(target.global_position - origin)
	return clampf(angle, -deg_to_rad(limit_degrees), deg_to_rad(limit_degrees))


func _process_array(delta: float) -> void:
	# Ceiling optics: track, freeze, then hold a converging V of cutting beams. A firing beam never moves.
	optic_clock -= delta
	var live_optics: Array = optics.filter(func(optic): return optic.health > 0)
	match optic_cycle:
		OpticCycle.REST:
			if optic_clock <= 0.0 and not live_optics.is_empty():
				optic_cycle = OpticCycle.AIM
				optic_clock = 1.0
				for i in optics.size():
					if optics[i].health > 0: optic_beams[i].set_state(Beam.State.WARN)
		OpticCycle.AIM:
			for i in optics.size():
				if optics[i].health <= 0: continue
				# Track until the lock window, then hold the line so the shot can be read and stepped out of.
				if optic_clock > AIM_LOCK:
					var desired := _target_angle_from(optics[i].global_position, 55.0)
					optics[i].aim_angle = rotate_toward(optics[i].aim_angle, desired, deg_to_rad(100.0) * delta)
				optics[i].charge = clampf(1.0 - optic_clock, 0.0, 1.0)
			if optic_clock <= 0.0:
				optic_cycle = OpticCycle.FIRE
				optic_clock = 2.4
				for i in optics.size():
					if optics[i].health > 0: optic_beams[i].set_state(Beam.State.ON)
		OpticCycle.FIRE:
			if optic_clock <= 0.0:
				optic_cycle = OpticCycle.REST
				optic_clock = 2.0
				for i in optics.size():
					optic_beams[i].set_state(Beam.State.OFF)
					optics[i].charge = 0.0
	for i in optics.size():
		optic_beams[i].rotation = optics[i].aim_angle
	# Wall optics: each is a scan carriage that steps down its inner face. At every stop its horizontal bar
	# (the near 62% of the corridor) warns, then fires in place; the carriage only travels with the bar off.
	# Shooting it means standing under it and stepping out of each stop's line as it comes down.
	for i in bulkheads.size():
		var bulkhead: Node2D = bulkheads[i]
		var beam: Node2D = bulkhead.beam
		var carriage: Node2D = bulkhead.optic
		if carriage.health <= 0:
			continue
		band_clock[i] -= delta
		match band_state[i]:
			Scan.REST:
				carriage.position.y = Bulkhead.OPTIC_Y
				carriage.charge = 0.0
				if band_clock[i] <= 0.0:
					band_stop[i] = 0
					_scan_move(i, carriage.position.y)
			Scan.MOVE:
				var progress := 1.0 - clampf(band_clock[i] / SCAN_MOVE, 0.0, 1.0)
				carriage.position.y = lerpf(band_from[i], SCAN_STOPS[band_stop[i]], smoothstep(0.0, 1.0, progress))
				if band_clock[i] <= 0.0:
					carriage.position.y = SCAN_STOPS[band_stop[i]]
					band_state[i] = Scan.WARN
					band_clock[i] = SCAN_WARN
					# The wall holds its breath while this bar is live, so the beam cannot slide either.
					bulkhead.breathing = false
					beam.set_length(bulkhead.corridor_width * 0.62)
					beam.set_state(Beam.State.WARN)
			Scan.WARN:
				carriage.charge = clampf(1.0 - band_clock[i] / SCAN_WARN, 0.0, 1.0)
				if band_clock[i] <= 0.0:
					band_state[i] = Scan.FIRE
					band_clock[i] = SCAN_FIRE
					beam.set_state(Beam.State.ON)
			Scan.FIRE:
				if band_clock[i] <= 0.0:
					beam.set_state(Beam.State.OFF)
					carriage.charge = 0.0
					bulkhead.breathing = true
					if band_stop[i] < SCAN_STOPS.size() - 1:
						band_stop[i] += 1
						_scan_move(i, carriage.position.y)
					else:
						band_state[i] = Scan.RETURN
						band_clock[i] = SCAN_RETURN
						band_from[i] = carriage.position.y
			Scan.RETURN:
				# The carriage winds back up its rail, still a target on the way.
				var back := 1.0 - clampf(band_clock[i] / SCAN_RETURN, 0.0, 1.0)
				carriage.position.y = lerpf(band_from[i], Bulkhead.OPTIC_Y, smoothstep(0.0, 1.0, back))
				if band_clock[i] <= 0.0:
					band_state[i] = Scan.REST
					band_clock[i] = SCAN_REST
		beam.position = carriage.position
		carriage.aim_angle = -bulkhead.side * PI * 0.5


func _scan_move(i: int, from_y: float) -> void:
	band_state[i] = Scan.MOVE
	band_clock[i] = SCAN_MOVE
	band_from[i] = from_y


func _on_optic_destroyed(optic: Node2D, beam: Node2D) -> void:
	beam.set_state(Beam.State.OFF)
	# A carriage killed mid-shot lets its wall breathe again.
	for bulkhead in bulkheads:
		if bulkhead.optic == optic and phase == 1 and not transitioning:
			bulkhead.breathing = true
	pulse.emit(0.6)
	jitter_left = 0.45
	_sparks(optic.global_position, 10)
	_check_section_cleared()


func _transition_to_press() -> void:
	# Defenses gone: the control system faults, the ceiling armor splits, and the press is thrown in as a last resort.
	section_changed.emit("SYSTEM FAULT")
	pulse.emit(1.6)
	jitter_left = 1.5
	fault_left = 1.5
	for bulkhead in bulkheads:
		bulkhead.breathing = false
		bulkhead.move_to(WALL_REST, 1.0)
	var split := create_tween()
	split.tween_property(self, "armor_split", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	split.parallel().tween_property(self, "glimpse", 1.0, 0.7)
	split.tween_interval(0.5)
	split.tween_property(self, "glimpse", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await split.finished
	if not _alive(): return
	section_changed.emit("OVERRIDE / MAW PRESS")
	for link in links: link.visible = true
	# The split armor lifts out of the way so the whole press frame and its rams come into view.
	var engage := create_tween()
	engage.tween_property(self, "upper_y", 96.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	engage.parallel().tween_property(self, "lower_y", 340.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	engage.parallel().tween_property(self, "ceiling_y", 22.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await engage.finished
	if not _alive(): return
	_begin_section(2)


# ---------------------------------------------------------------- 03 / MAW PRESS

func _press_tween() -> Tween:
	if motion != null and motion.is_valid(): motion.kill()
	motion = create_tween()
	return motion


func _telegraph(seconds: float, walls: bool) -> void:
	press_warning = 1.0
	if walls:
		for bulkhead in bulkheads: bulkhead.begin_warning(seconds)
	await _pause_for(seconds)
	press_warning = 0.0


func _contraction_loop(run: int) -> void:
	var order := [Contraction.SQUEEZE_LR, Contraction.SQUEEZE_UD, Contraction.TWIST, Contraction.SNAP]
	while _step_valid(run):
		var step: int = order[contraction_index % order.size()]
		contraction_index += 1
		# Every cut link slows the next command: the core is losing the bay.
		var warn := 0.8 + 0.3 * links_cut
		match step:
			Contraction.SQUEEZE_LR:
				await _telegraph(warn, true)
				if not _step_valid(run): return
				for bulkhead in bulkheads: bulkhead.move_to(62.0, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT, true)
				await _pause_for(1.0)
				if not _step_valid(run): return
				_spit_gap_wall()
				await _pause_for(1.5)
				if not _step_valid(run): return
				for bulkhead in bulkheads: bulkhead.move_to(WALL_REST, 1.4, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
			Contraction.SQUEEZE_UD:
				await _telegraph(warn, false)
				if not _step_valid(run): return
				var close := _press_tween()
				close.tween_property(self, "upper_y", 150.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				close.parallel().tween_property(self, "lower_y", 290.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				await close.finished
				if not _step_valid(run): return
				_spit_crush_fan()
				await _pause_for(1.2)
				if not _step_valid(run): return
				var release := _press_tween()
				release.tween_property(self, "upper_y", 96.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				release.parallel().tween_property(self, "lower_y", 340.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			Contraction.TWIST:
				var wall: Node2D = bulkheads[contraction_index % 2]
				wall.lunge(110.0, warn, 0.8)
				await _pause_for(warn + 0.25 + 0.8 + 1.2)
			Contraction.SNAP:
				await _telegraph(warn, true)
				if not _step_valid(run): return
				pulse.emit(1.4)
				for bulkhead in bulkheads: bulkhead.move_to(70.0, 0.35, Tween.TRANS_BACK, Tween.EASE_OUT, true)
				var snap := _press_tween()
				snap.tween_property(self, "upper_y", 170.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				snap.parallel().tween_property(self, "lower_y", 280.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				await snap.finished
				if not _step_valid(run): return
				for i in 3:
					_sparks(Vector2(HALF_W + randf_range(-120.0, 120.0), upper_y - 12.0), 6)
				await _pause_for(0.5)
				if not _step_valid(run): return
				for bulkhead in bulkheads: bulkhead.move_to(WALL_REST, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
				var open := _press_tween()
				open.tween_property(self, "upper_y", 96.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				open.parallel().tween_property(self, "lower_y", 340.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _pause_for(1.0)


func _step_valid(run: int) -> bool:
	return _alive() and run == contraction_run and phase == 2 and not transitioning


func _spit_gap_wall() -> void:
	# Shot from under the teeth, following the V of the platen.
	var sequence := Pattern.new()
	sequence.build({"kind": "gap_wall", "gap": randi_range(1, 12), "drift": 1 if randf() < 0.5 else -1, "y": 4.0, "slope": 0.16})
	spit_barrage.play(sequence, press_top, world)


func _spit_crush_fan() -> void:
	var sequence := Pattern.new()
	sequence.build({"kind": "crush_fan"})
	spit_barrage.play(sequence, press_apex, world)


func _on_link_cut(link: Node2D) -> void:
	links_cut += 1
	pulse.emit(0.7)
	_sparks(link.global_position, 12)
	for i in 2:
		Debris.spawn(world, link.global_position, Debris.Kind.ROD, randf_range(4.0, 6.0))
	_check_section_cleared()


func _shutdown() -> void:
	# Last link cut: the fight is over. The bay freezes where it stands; _process_destruction plays the rest.
	defeated = true
	phase = 3
	contraction_run += 1
	if motion != null and motion.is_valid(): motion.kill()
	press_shake = 0.0
	press_warning = 0.0
	for bulkhead in bulkheads:
		if bulkhead.motion != null and bulkhead.motion.is_valid(): bulkhead.motion.kill()
		bulkhead.breathing = false
		bulkhead.warning_left = 0.0
		bulkhead.warning = 0.0
	section_changed.emit("LINK SEVERED")
	destruction_started.emit()
	pulse.emit(1.2)


# ---------------------------------------------------------------- shutdown

## Frozen → lights die → hydraulics let go → the core that ran it all hangs in the open → it burns out.
func _process_destruction(delta: float) -> void:
	if destruction_complete: return
	destruction_age += delta
	var t := destruction_age
	power = 1.0 - pow(clampf(t, 0.0, 1.0), 3.0)
	if ending_step == 0 and t >= POWER_DOWN_AT:
		ending_step = 1
		section_changed.emit("POWER DOWN")
		for bulkhead in bulkheads:
			bulkhead.breathe_center = Bulkhead.PARKED
			bulkhead.move_to(Bulkhead.PARKED, 2.2, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		var release := _press_tween()
		release.tween_property(self, "upper_y", 26.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		release.parallel().tween_property(self, "lower_y", 392.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		release.parallel().tween_property(self, "ceiling_y", 12.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if ending_step == 1 and t >= CORE_REVEAL_AT:
		# The coffin-sized command module drops out of the ceiling split.
		ending_step = 2
		core.visible = true
		core.position = Vector2(HALF_W, ceiling_y + 4.0)
		var drop := create_tween()
		drop.tween_property(core, "position:y", 110.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if ending_step == 2 and t >= CORE_EXPOSED_AT:
		ending_step = 3
		section_changed.emit("CORE EXPOSED")
	if ending_step == 3 and t >= OVERLOAD_AT:
		ending_step = 4
		core_origin = core.position
		section_changed.emit("CORE / OVERLOAD")
		pulse.emit(1.8)
		_sparks(core_origin, 16)
		var kinds := [Debris.Kind.PLATE, Debris.Kind.GEAR, Debris.Kind.ROD]
		for i in 6:
			Debris.spawn(world, core_origin, kinds[i % kinds.size()], randf_range(3.0, 6.0))
	if ending_step == 4 and t >= SAG_AT:
		ending_step = 5
		for bulkhead in bulkheads:
			bulkhead.move_to(-130.0, 3.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	# Command links: the core reaches for the dead machinery, stutters, then lets go.
	link_alpha = smoothstep(2.6, 3.0, t) * (1.0 - smoothstep(OVERLOAD_AT, OVERLOAD_AT + 0.8, t))
	link_flash = randf() if t >= CORE_EXPOSED_AT and t < OVERLOAD_AT else maxf(0.0, link_flash - delta * 2.0)
	core.charge = randf_range(0.4, 1.0) if t >= CORE_EXPOSED_AT and t < OVERLOAD_AT else 0.0
	var bursts := [[0.0, 30.0], [0.2, 22.0], [0.45, 40.0], [0.9, 16.0]]
	while ending_step >= 4 and burst_step < bursts.size() and t >= OVERLOAD_AT + float(bursts[burst_step][0]):
		Destruction.spawn(world, core_origin + Vector2(randf_range(-8, 8), randf_range(-8, 8)), float(bursts[burst_step][1]), burst_step == 2)
		pulse.emit(0.6)
		burst_step += 1
	if ending_step >= 4:
		core.visible = t < OVERLOAD_AT + 0.05
	if ending_step >= 5:
		# Dead machinery sags out of the way and the route opens.
		var sag := smoothstep(SAG_AT, SAG_AT + 2.6, t)
		upper_y = lerpf(26.0, -30.0, sag)
		lower_y = lerpf(392.0, 430.0, sag)
		ceiling_y = lerpf(12.0, -50.0, sag)
	if background != null:
		if t < OVERLOAD_AT + 0.8:
			background.speed_scale = 0.0
		elif t < OVERLOAD_AT + 1.6:
			background.speed_scale = lerpf(0.0, 4.5, smoothstep(OVERLOAD_AT + 0.8, OVERLOAD_AT + 1.6, t))
		else:
			background.speed_scale = lerpf(4.5, 1.0, smoothstep(OVERLOAD_AT + 1.6, SHUTDOWN_AT - 0.2, t))
	if t >= SHUTDOWN_AT:
		destruction_complete = true
		section_changed.emit("RECYCLER / SHUTDOWN")
		destruction_finished.emit()


# ---------------------------------------------------------------- frame

func _physics_process(delta: float) -> void:
	age += delta
	if fault_left > 0.0:
		# Control faults: lamps stutter and the walls throw sparks.
		fault_left = maxf(0.0, fault_left - delta)
		power = randf_range(0.15, 1.0) if fault_left > 0.0 else 1.0
		spark_clock -= delta
		if spark_clock <= 0.0:
			spark_clock = 0.12
			var wall: Node2D = bulkheads.pick_random()
			_sparks(Vector2(wall.face_x(), randf_range(90.0, 330.0)), 4)
	elif phase == 2 and not transitioning:
		# Overdriven press: the platen throws sparks at random.
		spark_clock -= delta
		if spark_clock <= 0.0:
			spark_clock = randf_range(0.6, 1.3)
			_sparks(Vector2(HALF_W + randf_range(-140.0, 140.0), upper_y - 20.0), 5)
	for bulkhead in bulkheads:
		bulkhead.power = power
	if jitter_left > 0.0:
		jitter_left = maxf(0.0, jitter_left - delta)
		for bulkhead in bulkheads:
			bulkhead.jitter = randf_range(-5.0, 5.0) if jitter_left > 0.0 else 0.0
			bulkhead.inset = bulkhead.inset
	elif bulkheads[0].jitter != 0.0:
		for bulkhead in bulkheads:
			bulkhead.jitter = 0.0
			bulkhead.inset = bulkhead.inset
	upper_closing = upper_y > _last_upper + 0.01
	lower_closing = lower_y < _last_lower - 0.01
	_last_upper = upper_y
	_last_lower = lower_y
	_sync_geometry()
	overlay.queue_redraw()
	backing.queue_redraw()
	command_overlay.queue_redraw()
	if defeated:
		_process_destruction(delta)
		return
	var width: float = bulkheads[1].face_x() - bulkheads[0].face_x()
	for bulkhead in bulkheads:
		bulkhead.corridor_width = width
	if transitioning: return
	section_age += delta
	match phase:
		0: _process_bulkheads(delta)
		1: _process_array(delta)


func _sync_geometry() -> void:
	for i in halves.size():
		var side := -1.0 if i == 0 else 1.0
		halves[i].position.x = side * 40.0 * armor_split
	# Overdriven hydraulics stutter while the press travels or winds up; it sits still otherwise.
	var shake := Vector2.ZERO
	if press_shake > 0.0 and (upper_closing or lower_closing or press_warning > 0.0):
		shake = Vector2(randf_range(-press_shake, press_shake), randf_range(-press_shake, press_shake))
	press_top.position = Vector2(HALF_W, upper_y) + shake
	press_bottom.position = Vector2(HALF_W, lower_y) - shake
	for i in links.size():
		links[i].position = Vector2(LINK_X[i], _press_base(LINK_X[i]) + 12.0)
	var flush := press_warning * (0.5 + 0.5 * sin(age * 14.0))
	for visual in [press_visual_top, press_visual_bottom]:
		Neon.structure(visual, power, flush)
	for half in halves:
		Neon.structure(half.get_child(0), power)
	for node in ram_nodes:
		node.queue_redraw()


func player_bounds() -> Rect2:
	var low := Vector2(maxf(8.0, bulkheads[0].face_x() + 7.0), maxf(8.0, maxf(ceiling_y, upper_y) + 10.0))
	var high := Vector2(minf(float(Playfield.SIZE.x) - 8.0, bulkheads[1].face_x() - 7.0), minf(352.0, lower_y - 10.0))
	return Rect2(low, high - low)


func _process(_delta: float) -> void:
	if defeated or not is_instance_valid(target): return
	var bounds := player_bounds()
	var point := target.position
	var pushed := false
	# Walls hurt only while a telegraphed move drives them in; breathing and repositioning just shove.
	if point.x < bounds.position.x:
		point.x = bounds.position.x
		pushed = pushed or (bulkheads[0].closing and bulkheads[0].crushing)
	elif point.x > bounds.end.x:
		point.x = bounds.end.x
		pushed = pushed or (bulkheads[1].closing and bulkheads[1].crushing)
	if point.y < bounds.position.y:
		point.y = bounds.position.y
		pushed = pushed or upper_closing or phase == -1
	elif point.y > bounds.end.y:
		point.y = bounds.end.y
		pushed = pushed or lower_closing
	if point == target.position: return
	target.position = point
	if pushed: _crush()


func _crush() -> void:
	var hurtbox := target.get_node_or_null("PlayerHitPoint/HurtboxComponent") as HurtboxComponent
	if hurtbox == null or hurtbox.is_invincible: return
	hurtbox.hurt.emit(crush_hitbox)
	pulse.emit(0.6)


# ---------------------------------------------------------------- drawing

func _draw_backing() -> void:
	backing.draw_rect(Rect2(-150, -420, 300, 418), Color(0.022, 0.016, 0.04))
	# Sparse, dim trusses behind the cut-out mask; they never compete with the armor.
	for row in 9:
		var y := -100.0 - row * 36.0
		Neon.line(backing, Vector2(-150, y), Vector2(150, y), STRUCTURE, 1.0, 0.1)
		for side in [-1.0, 1.0]:
			Neon.line(backing, Vector2(side * 135, y), Vector2(side * 95, y - 30), STRUCTURE, 1.0, 0.1)
	if glimpse > 0.0:
		# Deep in the split: a red scanner walking a slit. The core, not yet shown.
		backing.draw_rect(Rect2(-16, -74, 32, 8), Color(0.0, 0.0, 0.0, glimpse))
		var x := sin(age * 5.0) * 12.0
		backing.draw_circle(Vector2(x, -70), 8.0 * glimpse, Color(1.6, 0.15, 0.2, 0.22 * glimpse))
		backing.draw_rect(Rect2(x - 2.5, -72, 5, 4), Color(2.8, 0.3, 0.3, glimpse))


func _draw_overlay() -> void:
	# Ceiling-line lamps: violet at rest, red before a press command, dark when the power dies.
	var level := lerpf(0.1, 1.0, power)
	for i in 19:
		var x := -144.0 + i * 16.0
		if armor_split > 0.0:
			if i == 9: continue
			x += signf(x) * 40.0 * armor_split
		var color := Color(0.4, 0.22, 0.7)
		if press_warning > 0.0 and int(age * 10.0) % 2 == 0:
			color = Color(2.2, 0.3, 0.25)
		overlay.draw_rect(Rect2(x - 1.5, -3.0, 3, 2), Color(color.r * level, color.g * level, color.b * level))


## Hydraulic rams: barrels are fixed in the bay frame, polished rods travel with the platen.
func _draw_rams(node: Node2D, top: bool) -> void:
	var platen_back := -PRESS_DEPTH if top else PRESS_DEPTH
	var mouth := (-40.0 - upper_y) if top else (420.0 - lower_y)
	var away := -1.0 if top else 1.0
	var moving := upper_closing if top else lower_closing
	var level := lerpf(0.12, 0.65, power)
	for x in RAM_X:
		for offset in [-7.0, 7.0]:
			Neon.line(node, Vector2(x + offset, mouth), Vector2(x + offset, mouth + away * 300.0), STRUCTURE, 1.5, level * 0.6)
		if (mouth - platen_back) * away > 0.0:
			Neon.line(node, Vector2(x, mouth), Vector2(x, platen_back), STRUCTURE, 3.0, level + (0.2 if moving else 0.0))
		Neon.line(node, Vector2(x - 10.0, mouth), Vector2(x + 10.0, mouth), STRUCTURE, 2.0, level)


## Shutdown: command links flowing from the exposed core to the machinery it drove; they stutter before it dies.
func _draw_command_links() -> void:
	if link_alpha <= 0.0 or not core.visible: return
	var origin := core.position
	var anchors := [
		Vector2(maxf(2.0, bulkheads[0].face_x()), 206.0),
		Vector2(minf(float(Playfield.SIZE.x) - 2.0, bulkheads[1].face_x()), 206.0),
		Vector2(HALF_W, maxf(upper_y, ceiling_y) - 2.0),
	]
	var color := Color(1.2 + link_flash * 1.6, 0.22 + link_flash * 0.8, 0.26 + link_flash * 0.6, (0.3 + link_flash * 0.6) * link_alpha)
	var width := 1.2 + link_flash * 1.4
	var flow := fmod(age * 40.0, 11.0)
	for anchor in anchors:
		var span: Vector2 = anchor - origin
		var length := span.length()
		if length < 1.0: continue
		var direction := span / length
		var t := flow
		while t < length:
			command_overlay.draw_line(origin + direction * t, origin + direction * minf(t + 6.0, length), color, width)
			t += 11.0
