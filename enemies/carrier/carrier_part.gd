extends Node2D
## Independent destructible carrier hardware; no run rewards or Enemy lifecycle.
signal damaged(amount: int)
signal destroyed
signal launch_requested(slot: int)
signal stage_changed(stage: int)

enum { TURRET = 0, HANGAR = 1, BRIDGE = 2, ESCORT = 4, ENGINE = 5 }
const Neon = preload("res://enemies/carrier/carrier_neon_visual.gd")
const Beam = preload("res://enemies/carrier/carrier_beam.gd")
const CRIMSON := Color(1.0, 0.08, 0.26)
const EXHAUST := Color(1.0, 0.32, 0.1)
const WARN_TIME := 0.95
const LOCK_TIME := 0.25
const HANGAR_CLOSED_DAMAGE := 0.35
const DOOR_LEAD := 1.6
const DOOR_HOLD := 0.6
const PLUME_PERIOD := 7.0
const PLUME_CHARGE := 1.1
const PLUME_FIRE := 1.8
const LASER_CHARGE := 1.3
const LASER_LOCK := 0.35
const LASER_FIRE := 1.6
const LASER_SWEEP := 20.0
## Bridge main cannon: twin rails that split in overdrive to frame the laser.
const CANNON_MUZZLE := 54.0
const CANNON_SPLIT := 4.5
const CANNON_PINK := Color(1.0, 0.25, 0.6)
## Hangar sortie timeline (seconds on launch_clock before the first launch):
## beacons from DOOR_LEAD, blast doors open between DOOR_OPEN_START and
## DOOR_OPEN_START - DOOR_OPEN_TIME, then the lift rises until launch.
const DOOR_OPEN_START := 1.0
const DOOR_OPEN_TIME := 0.6
const DOOR_CLOSE := 0.3
## Bay opening inside carrier_hangar.svg, in local pixels.
const BAY := Rect2(-14.5, -27, 29, 61)
const FIGHTER_TEX := preload("res://assets/enemies/enemy_interceptor.svg")
const STRIKER_TEX := preload("res://assets/enemies/enemy_striker.svg")
var maximum := 120
var health := 120
var mode := TURRET
var section := 0
var required := true
var active := false
var age := 0.0
var cooldown := 0.0
var warning := false
var hit_flash := 0.0
var world: Node2D
var target: Node2D
var hurtbox: HurtboxComponent
var barrage: BarragePlayer
var visual: Node2D
var pattern_index := 0
var firing_side := 1.0
var attack_cycle := 0
var current_variant := 0
var fire_permission := true
var pivot: Node2D
var gun: Node2D
var muzzle: Node2D
var muzzle_flash: Polygon2D
var fx: Node2D
var rails: Array[Node2D] = []
var housing: Node2D
var cannon_fx: Node2D
var cannon_back: Node2D
var beam: Node2D
var recoil := 0.0
var gun_scale := 0.36
## 0 = stowed on the approaching hull, 1 = deployed for its section.
var deploy := 0.0
var launch_charge := 0.0
var launch_flash := 0.0
var launch_clock := 2.0
var launch_remaining := 0
var launch_gap := 0.0
var door_hold := 0.0
var sortie_index := 0
var sortie_kind := 0
var armor_carry := 0.0
var door_close_left := 0.0
var door_seen := 0.0
var slam_flash := 0.0
var plume_clock := 1.5
var plume_pending := false
var stage := 0
var armor_open := 0.0
var laser_sweep_dir := 1.0
var laser_firing := false
var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var fx_clock := 0.0
var scorch := PackedVector2Array()

func destruction_radius() -> float:
	match mode:
		HANGAR: return 40.0
		BRIDGE: return 54.0
		ESCORT: return 16.0
		ENGINE: return 18.0
	return 21.0

func energy() -> Color:
	if mode == ENGINE: return EXHAUST
	return CRIMSON

func _ready() -> void:
	health = maximum
	rng.seed = hash(position) + mode
	var texture: Texture2D = preload("res://assets/enemies/carrier_turret.svg")
	var visual_scale := 0.25
	match mode:
		HANGAR:
			texture = preload("res://assets/enemies/carrier_hangar.svg")
			visual_scale = 0.5
		BRIDGE:
			texture = preload("res://assets/enemies/carrier_bridge.svg")
			visual_scale = 0.6
		ENGINE:
			texture = preload("res://assets/enemies/carrier_engine.svg")
			visual_scale = 0.45
	visual = Neon.make(texture, visual_scale, energy())
	add_child(visual)
	if mode in [TURRET, BRIDGE, ESCORT]:
		pivot = Node2D.new()
		add_child(pivot)
		if mode == BRIDGE:
			_build_cannon()
		else:
			gun_scale = 0.36
			gun = Neon.make(preload("res://assets/enemies/carrier_gun.svg"), gun_scale, Color(1.0,0.12,0.3))
			pivot.add_child(gun)
		muzzle = Node2D.new()
		muzzle.position.y = CANNON_MUZZLE if mode == BRIDGE else 52 * gun_scale
		pivot.add_child(muzzle)
	else:
		muzzle = Node2D.new()
		muzzle.position.y = 14 if mode == ENGINE else 30
		add_child(muzzle)
	muzzle_flash = Polygon2D.new()
	muzzle_flash.polygon = PackedVector2Array([Vector2(-4,0),Vector2(-2,7),Vector2(0,13),Vector2(2,7),Vector2(4,0)])
	muzzle_flash.color = Color(2.0,1.1,0.7)
	muzzle.add_child(muzzle_flash)
	if mode == ENGINE:
		beam = Beam.new()
		beam.length = 420
		beam.visual_width = 24
		beam.hit_width = 12
		beam.glow_color = EXHAUST
		beam.hot_color = Color(1.0, 0.85, 0.55)
		muzzle.add_child(beam)
	elif mode == BRIDGE:
		beam = Beam.new()
		beam.length = 520
		beam.visual_width = 18
		beam.hit_width = 8
		beam.glow_color = Color(1.0, 0.12, 0.32)
		beam.hot_color = Color(1.0, 0.86, 0.92)
		muzzle.add_child(beam)
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	match mode:
		HANGAR: rectangle.size = Vector2(42,56)
		BRIDGE: rectangle.size = Vector2(56,50)
		ENGINE: rectangle.size = Vector2(24,26)
		_: rectangle.size = Vector2(22,24)
	shape.shape = rectangle
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hurt.connect(func(hit: HitboxComponent): take_damage(hit.damage))
	barrage = BarragePlayer.new()
	add_child(barrage)
	barrage.finished.connect(func(): cooldown = rest_time())
	barrage.volley_fired.connect(func(_projectiles): recoil = 1.0)
	# Damage sparks, smoke and wreck scorch sit above every visual layer.
	fx = Node2D.new()
	fx.draw.connect(_draw_fx)
	add_child(fx)
	set_active(active)

func _build_cannon() -> void:
	gun = Node2D.new()
	pivot.add_child(gun)
	# Dark silhouette separates the cannon from the tower art beneath it.
	cannon_back = Node2D.new()
	cannon_back.draw.connect(_draw_cannon_back)
	gun.add_child(cannon_back)
	for side in [-1, 1]:
		# One rail art, mirrored for the starboard side.
		var rail := Neon.make(preload("res://assets/enemies/carrier_cannon_rail.svg"), 0.25, CRIMSON)
		rail.scale.x = -side
		gun.add_child(rail)
		rails.append(rail)
	cannon_fx = Node2D.new()
	cannon_fx.draw.connect(_draw_cannon)
	gun.add_child(cannon_fx)
	housing = Neon.make(preload("res://assets/enemies/carrier_cannon_mount.svg"), 0.5, CRIMSON)
	gun.add_child(housing)

## 0..1 laser build-up: charge ramp, then held at 1 while the beam fires.
func laser_charge() -> float:
	if laser_firing: return 1.0
	if warning and current_variant == 3: return clampf(1.0 - cooldown / LASER_CHARGE, 0.0, 1.0)
	return 0.0

func rest_time() -> float:
	if mode == BRIDGE: return [2.0, 1.6, 1.0][stage]
	return 1.8

func set_active(value: bool) -> void:
	active = value and health > 0
	if hurtbox != null: hurtbox.is_invincible = not active
	if not active:
		if barrage != null: barrage.stop()
		if beam != null: beam.stop()
		launch_remaining = 0
		launch_charge = 0
		door_hold = 0
		door_close_left = 0
		recoil = 0
		plume_pending = false
		laser_firing = false
	warning = false
	_update_visual()
	queue_redraw()

func door_opening() -> float:
	if mode != HANGAR or health <= 0 or not active: return 0.0
	if launch_remaining > 0 or door_hold > 0: return 1.0
	if door_close_left > 0: return smoothstep(0.0, DOOR_CLOSE, door_close_left)
	return smoothstep(DOOR_OPEN_START, DOOR_OPEN_START - DOOR_OPEN_TIME, launch_clock)

## Beacon strength: spins up at DOOR_LEAD and stays on until the doors seal.
func bay_alert() -> float:
	if mode != HANGAR or health <= 0 or not active: return 0.0
	if launch_remaining > 0 or door_hold > 0 or door_close_left > 0: return 1.0
	return clampf((DOOR_LEAD - launch_clock) / 0.25, 0.0, 1.0)

## 0..1 lift height of the aircraft waiting on the elevator.
func lift_rise() -> float:
	if launch_remaining > 0: return clampf(1.0 - launch_gap / 0.3, 0.0, 1.0) if launch_gap > 0 else 1.0
	return smoothstep(DOOR_OPEN_START - DOOR_OPEN_TIME, 0.0, launch_clock)

func take_damage(amount: int) -> void:
	if not active or health <= 0: return
	var incoming := float(maxi(amount, 0))
	var deflected := mode == HANGAR and door_opening() < 0.5
	if deflected:
		incoming *= HANGAR_CLOSED_DAMAGE
		# Shutter hits spark grey instead of flashing: white means real damage.
		for i in 2:
			_emit(Vector2(rng.randf_range(-10, 10), 30), Vector2(rng.randf_range(-50, 50), rng.randf_range(10, 40)), 0.18, 2)
	else:
		hit_flash = 0.12
	armor_carry += incoming
	var applied := mini(health, int(floor(armor_carry + 0.0001)))
	armor_carry -= applied
	if applied == 0: return
	health -= applied
	damaged.emit(applied)
	if health == 0:
		set_active(false)
		_make_scorch()
		preload("res://enemies/carrier/carrier_destruction_effect.gd").spawn(world, global_position, destruction_radius(), mode in [HANGAR, BRIDGE])
		destroyed.emit()
	elif mode == BRIDGE:
		_check_bridge_stage()
	queue_redraw()

func _check_bridge_stage() -> void:
	var next := 2 if health <= maximum * 0.15 else (1 if health <= maximum * 0.5 else 0)
	if next <= stage: return
	var entering_overdrive := stage == 0
	stage = next
	if entering_overdrive:
		# Break off the current attack and open the core before the laser cycle.
		barrage.stop()
		beam.stop()
		laser_firing = false
		warning = false
		cooldown = 1.4
		attack_cycle = 0
		var opening := create_tween()
		opening.tween_property(self, "armor_open", 1.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stage_changed.emit(stage)

func _physics_process(delta: float) -> void:
	hit_flash = maxf(0, hit_flash - delta)
	launch_flash = maxf(0, launch_flash - delta)
	slam_flash = maxf(0, slam_flash - delta)
	recoil = move_toward(recoil, 0, delta * 7)
	if active:
		age += delta
		match mode:
			HANGAR: _process_hangar(delta)
			ENGINE: _process_engine(delta)
			_: _process_weapon(delta)
	_process_fx(delta)
	_update_visual()
	queue_redraw()
	fx.queue_redraw()

func _process_hangar(delta: float) -> void:
	launch_clock -= delta
	if launch_clock <= 0:
		launch_clock += 6.0
		launch_remaining = 3
		launch_gap = 0
		# Sorties alternate: spread-fire fighters, then catapult strikers.
		sortie_kind = sortie_index % 2
		sortie_index += 1
	if launch_remaining > 0:
		launch_gap -= delta
		if launch_gap <= 0:
			launch_requested.emit(3 - launch_remaining)
			launch_remaining -= 1
			launch_gap = 0.35
			if launch_remaining == 0: door_hold = DOOR_HOLD
	if door_hold > 0:
		door_hold -= delta
		if door_hold <= 0:
			door_hold = 0
			door_close_left = DOOR_CLOSE
	elif door_close_left > 0:
		door_close_left -= delta
		if door_close_left <= 0:
			# Doors slam shut: seam flash and grey sparks.
			door_close_left = 0
			slam_flash = 0.15
			for i in 6:
				_emit(Vector2(rng.randf_range(-2, 2), rng.randf_range(BAY.position.y, BAY.end.y)), Vector2(rng.randf_range(-60, 60), rng.randf_range(-20, 20)), 0.2, 2)
	launch_charge = 1.0 if launch_remaining > 0 else clampf((DOOR_LEAD - launch_clock) / DOOR_LEAD, 0.0, 1.0)
	var opening := door_opening()
	if door_seen < 0.02 and opening >= 0.02:
		# Pressure vents as the seal breaks.
		for i in 8:
			var side := -1.0 if i % 2 == 0 else 1.0
			_emit(Vector2(side * 4.0, rng.randf_range(BAY.position.y, BAY.end.y)), Vector2(side * rng.randf_range(20, 45), rng.randf_range(-10, 10)), 0.7, 3)
	door_seen = opening

func _process_engine(delta: float) -> void:
	plume_clock -= delta
	if plume_clock <= 0:
		plume_clock += PLUME_PERIOD
		beam.charge(PLUME_CHARGE)
		plume_pending = true
	if plume_pending and beam.charge_left <= 0:
		plume_pending = false
		beam.fire(PLUME_FIRE)
	warning = plume_pending

func _process_weapon(delta: float) -> void:
	var laser := mode == BRIDGE and current_variant == 3
	var lock_window := LASER_LOCK if laser else LOCK_TIME
	if laser_firing:
		pivot.rotation = clampf(pivot.rotation + laser_sweep_dir * deg_to_rad(LASER_SWEEP) * delta, -deg_to_rad(70), deg_to_rad(70))
		if not beam.is_busy():
			laser_firing = false
			cooldown = rest_time()
		return
	# The final lock window and the aimed burst preserve the visible lock.
	if barrage.running and current_variant == 2:
		pivot.rotation = clampf(pivot.rotation + firing_side * deg_to_rad(58) * delta, -deg_to_rad(70), deg_to_rad(70))
	elif not barrage.running and not (warning and cooldown <= lock_window):
		var desired := 0.0
		if is_instance_valid(target):
			desired = clampf(Vector2.DOWN.angle_to(target.global_position - global_position), -deg_to_rad(70), deg_to_rad(70))
		if warning and current_variant == 0: desired = firing_side * deg_to_rad(9)
		if warning and current_variant == 2: desired = -firing_side * deg_to_rad(32)
		if warning and current_variant == 4: desired = 0.0
		pivot.rotation = rotate_toward(pivot.rotation, desired, deg_to_rad(100) * delta)
	if barrage.running: return
	cooldown -= delta
	if cooldown > 0: return
	if not warning:
		if not fire_permission: return
		current_variant = (pattern_index + attack_cycle) % 3
		if mode == ESCORT: current_variant = 1
		if mode == BRIDGE and stage > 0: current_variant = [3, 0, 4][attack_cycle % 3]
		warning = true
		cooldown = LASER_CHARGE if current_variant == 3 else WARN_TIME
		if current_variant == 3: beam.charge(LASER_CHARGE)
	else:
		warning = false
		attack_cycle += 1
		if current_variant == 3:
			# Sweep away from the locked side so the first dodge stays safe.
			laser_sweep_dir = -signf(pivot.rotation) if absf(pivot.rotation) > 0.05 else -firing_side
			laser_firing = true
			recoil = 1.0
			beam.fire(LASER_FIRE)
			return
		var sequence := preload("res://patterns/carrier_lab_pattern.gd").new()
		sequence.build({"mode": mode, "variant": current_variant})
		barrage.play(sequence, muzzle, world, target if is_instance_valid(target) else null)

func _update_visual() -> void:
	if visual == null: return
	var tint := energy()
	var charge := clampf(1.0 - cooldown / WARN_TIME, 0, 1) if warning else 0.0
	if mode == HANGAR: charge = door_opening()
	if mode == ENGINE: charge = 1.0 if (beam.firing or plume_pending) else 0.0
	var integrity := float(health) / maximum
	# Critical parts stutter so remaining HP reads without a bar.
	var flicker := 0.55 if integrity < 0.34 and health > 0 and sin(fx_clock * 37.0) > 0.6 else 1.0
	var readiness := lerpf(0.35, 1.0, deploy)
	visual.get_node("WideGlow").self_modulate = Color(tint, (0.22 + charge * 0.2) * readiness * flicker)
	visual.get_node("TightGlow").self_modulate = Color(tint, (0.55 + charge * 0.35) * readiness * flicker)
	var core := Color(1.0,0.91,0.95).lerp(Color(0.45,0.22,0.32), 1.0 - readiness)
	visual.get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else core * flicker
	visual.modulate = Color.WHITE if health > 0 else Color(0.16,0.1,0.16,0.5)
	if mode == BRIDGE:
		_update_cannon(charge, readiness, flicker)
	elif gun != null:
		visual.get_node("Core").self_modulate = Color(0.55,0.28,0.38) if hit_flash <= 0 else Color.WHITE
		gun.position.y = 16 * gun_scale - recoil * 3.5
		# Stowed guns sit folded inside their bearing plates on approach.
		gun.scale = Vector2.ONE * lerpf(0.45, 1.0, deploy)
		gun.modulate = visual.modulate
		var gun_core := Color(1.0 + charge,0.9 + charge * 0.3,0.95).lerp(Color(0.5,0.25,0.35), 1.0 - readiness)
		gun.get_node("Core").self_modulate = gun_core * flicker
		gun.get_node("TightGlow").self_modulate = Color(tint,(0.65 + charge * 0.35) * readiness)
		# The muzzle follows the physical recoil as well as the barrel angle.
		muzzle.position.y = (52 * gun_scale - recoil * 3.5) * gun.scale.y
	muzzle_flash.visible = health > 0 and recoil > 0.2 and not laser_firing
	muzzle_flash.scale = Vector2.ONE * recoil
	if mode == HANGAR:
		var opening := door_opening()
		# Closed shutters dim the hangar: bright = open = full damage.
		var open_core := Color(0.98,0.84,0.9).lerp(Color(0.65,0.35,0.45), 1.0 - integrity)
		var shut_core := Color(0.5,0.26,0.36)
		visual.get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else shut_core.lerp(open_core, opening) * flicker
		visual.get_node("WideGlow").self_modulate.a = lerpf(0.06, 0.22, opening)
		visual.get_node("TightGlow").self_modulate.a = lerpf(0.25, 0.75, opening)
	visual.scale = Vector2.ONE * (1.06 if hit_flash > 0 else 1.0)

func _update_cannon(charge: float, readiness: float, flicker: float) -> void:
	var heat := laser_charge()
	var split := armor_open * CANNON_SPLIT
	var tint := CRIMSON.lerp(CANNON_PINK, armor_open)
	gun.scale = Vector2.ONE * lerpf(0.45, 1.0, deploy)
	gun.modulate = visual.modulate
	var rail_core := Color(0.95,0.82,0.88).lerp(Color(0.5,0.25,0.35), 1.0 - readiness)
	for i in rails.size():
		var side := -1.0 if i == 0 else 1.0
		# Rails slide back on recoil and apart in overdrive.
		rails[i].position = Vector2(side * (6.0 + split), 27.0 - recoil * 3.0)
		rails[i].get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else rail_core * flicker
		rails[i].get_node("TightGlow").self_modulate = Color(tint, (0.55 + 0.45 * maxf(charge, heat)) * readiness)
		rails[i].get_node("WideGlow").self_modulate = Color(tint, (0.15 + 0.35 * heat) * readiness)
	housing.get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else Color(0.8,0.6,0.7).lerp(Color(1.4,0.9,1.2), heat) * flicker
	housing.get_node("TightGlow").self_modulate = Color(tint, 0.6 * readiness)
	# Tower body stays dim like a turret bearing so the cannon reads on top.
	visual.get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else Color(0.62,0.33,0.45) * flicker
	visual.get_node("WideGlow").self_modulate.a *= 0.6
	visual.get_node("TightGlow").self_modulate.a *= 0.7
	cannon_back.queue_redraw()
	muzzle.position.y = (CANNON_MUZZLE - recoil * 3.0) * gun.scale.y
	cannon_fx.queue_redraw()

func _draw_cannon_back() -> void:
	var split := armor_open * CANNON_SPLIT
	var tip := CANNON_MUZZLE - recoil * 3.0
	var width := 10.0 + split
	cannon_back.draw_colored_polygon(PackedVector2Array([Vector2(-width, 4), Vector2(width, 4), Vector2(width, tip - 6), Vector2(4.0 + split, tip + 3), Vector2(-4.0 - split, tip + 3), Vector2(-width, tip - 6)]), Color(0.03, 0.015, 0.04, 0.92))
	cannon_back.draw_circle(Vector2.ZERO, 18.0, Color(0.03, 0.015, 0.04, 0.92))

func _draw_cannon() -> void:
	if health <= 0 or armor_open <= 0.05: return
	var heat := laser_charge()
	var split := armor_open * CANNON_SPLIT
	var tip := CANNON_MUZZLE - recoil * 3.0
	var pulse := 0.8 + 0.2 * sin(fx_clock * 40.0)
	# Charge channel framed by the split rails' flat inner edges.
	cannon_fx.draw_rect(Rect2(-split + 0.8, 8, (split - 0.8) * 2.0, tip - 10), Color(1.8, 0.3, 0.9, (0.2 + 0.6 * heat) * pulse))
	for side in [-1.0, 1.0]:
		cannon_fx.draw_line(Vector2(side * split, 8), Vector2(side * split, tip), Color(2.0, 0.7, 1.4, 0.3 + 0.7 * heat), 1.0)
	if heat > 0 and not laser_firing:
		# Motes run down the channel and converge on the emitter while charging.
		for i in 5:
			var y := 10.0 + fposmod(fx_clock * (50.0 + 150.0 * heat) + i * tip / 5.0, tip - 10.0)
			cannon_fx.draw_circle(Vector2(0, y), 0.8 + heat, Color(2.4, 1.3, 2.1, 0.9))
		for i in 6:
			var reach := (1.0 - fposmod(fx_clock * 2.2 + i / 6.0, 1.0)) * 16.0 * heat
			cannon_fx.draw_circle(Vector2(0, tip) + Vector2.from_angle(TAU * i / 6.0 + fx_clock) * reach, 0.9, Color(2.2, 0.9, 1.8, heat))
	var orb := 1.5 + heat * 5.0 + (1.5 * sin(fx_clock * 50.0) if laser_firing else 0.0)
	cannon_fx.draw_circle(Vector2(0, tip), orb * 1.9, Color(1.6, 0.3, 0.8, 0.2 + 0.3 * heat))
	cannon_fx.draw_circle(Vector2(0, tip), orb, Color(2.6, 1.8, 2.4, 0.5 + 0.5 * heat))

## Damage sparks, smoke and embers; purely visual and pause-safe.
func _process_fx(delta: float) -> void:
	fx_clock += delta
	var integrity := float(health) / maximum
	var size := destruction_radius()
	if health > 0 and integrity < 0.67 and rng.randf() < delta * (3.0 if integrity < 0.34 else 1.4):
		for i in 3:
			_emit(Vector2(rng.randf_range(-size, size) * 0.5, rng.randf_range(-size, size) * 0.5), Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30, 70), 0.25, 0)
	if (health == 0 or integrity < 0.34) and rng.randf() < delta * (5.0 if health == 0 else 3.0):
		_emit(Vector2(rng.randf_range(-size, size) * 0.4, 0), Vector2(rng.randf_range(-6, 6), rng.randf_range(18, 30)), 1.1, 1)
	for particle in particles:
		particle["life"] -= delta
		particle["p"] += particle["v"] * delta
	particles = particles.filter(func(item): return item["life"] > 0)

func _emit(origin: Vector2, velocity: Vector2, life: float, kind: int) -> void:
	if particles.size() > 40: return
	particles.append({"p": origin, "v": velocity, "life": life, "max": life, "kind": kind})

func _make_scorch() -> void:
	var size := destruction_radius() * 0.8
	scorch = PackedVector2Array()
	for i in 9:
		scorch.append(Vector2.from_angle(TAU * i / 9.0) * size * rng.randf_range(0.55, 1.0))

func _draw_fx() -> void:
	if not scorch.is_empty():
		fx.draw_colored_polygon(scorch, Color(0.05, 0.02, 0.05, 0.7))
		for i in 5:
			# Embers breathe slowly so the wreck keeps a faint heat signature.
			var ember := scorch[(i * 2) % scorch.size()] * 0.45
			var heat := 0.5 + 0.5 * sin(fx_clock * (2.0 + i) + i)
			fx.draw_circle(ember, 1.2, Color(1.6, 0.45, 0.15, 0.25 + heat * 0.5))
	for particle in particles:
		var fade: float = particle["life"] / particle["max"]
		if particle["kind"] == 0:
			fx.draw_line(particle["p"], particle["p"] - particle["v"] * 0.05, Color(2.0, 1.2, 0.6, fade), 1.0)
		elif particle["kind"] == 3:
			fx.draw_circle(particle["p"], lerpf(7.0, 2.0, fade), Color(0.85, 0.7, 0.8, 0.28 * fade))
		elif particle["kind"] == 2:
			fx.draw_line(particle["p"], particle["p"] - particle["v"] * 0.06, Color(0.75, 0.7, 0.8, fade * 0.8), 1.0)
		else:
			fx.draw_circle(particle["p"], lerpf(6.0, 2.5, fade), Color(0.12, 0.08, 0.12, 0.45 * fade))
	if health <= 0: return
	if mode == HANGAR:
		_draw_hangar_beacons()
	if mode == ENGINE:
		# Idle thrust flicker: the ship is visibly under way even between plumes.
		var flame := 12.0 + 6.0 * absf(sin(age * 24.0 + position.x))
		fx.draw_colored_polygon(PackedVector2Array([Vector2(-6, 14), Vector2(0, 14 + flame), Vector2(6, 14)]), Color(1.6, 0.55, 0.2, 0.7))
		fx.draw_colored_polygon(PackedVector2Array([Vector2(-2.5, 14), Vector2(0, 14 + flame * 0.6), Vector2(2.5, 14)]), Color(2.0, 1.6, 1.2, 0.9))
	elif mode == BRIDGE:
		# Radar mast sweep.
		var radar := Vector2(0, -40)
		var sweep := Vector2.from_angle(age * 3.0) * 11.0
		fx.draw_line(radar, radar + sweep, Color(1.5, 0.5, 0.6, 0.8), 1.0, true)
		fx.draw_arc(radar, 11.0, age * 3.0 - 0.9, age * 3.0, 8, Color(1.0, 0.3, 0.4, 0.3), 1.0, true)
		# Overdrive reactor ring around the cannon housing.
		if armor_open > 0.05:
			var pulse := 0.6 + 0.4 * sin(age * 6.0)
			fx.draw_arc(Vector2.ZERO, 19.0, 0, TAU, 32, Color(2.0, 0.4, 1.0, 0.45 * armor_open * pulse), 1.5, true)

func upcoming_kind() -> int:
	return sortie_kind if launch_remaining > 0 else sortie_index % 2

## Bay interior, lift with the waiting aircraft, pocket blast doors and exit rails.
## Drawn beneath the hangar frame art so door leaves slide into the wall pockets.
func _draw_hangar_bay() -> void:
	var alive := health > 0
	var opening := door_opening() if alive else 0.3
	var alert := bay_alert()
	draw_rect(BAY, Color("050711"))
	if alive and opening > 0.01:
		# Warm bay light spills toward the mouth as the doors part.
		for i in 6:
			var band := Rect2(BAY.position.x, BAY.position.y + BAY.size.y * i / 6.0, BAY.size.x, BAY.size.y / 6.0)
			draw_rect(band, Color(0.9, 0.32, 0.2, opening * (0.05 + 0.035 * i)))
		for side in [-1.0, 1.0]:
			for i in 8:
				# Bay-edge lights chase toward the mouth.
				var lit := posmod(i - int(age * 10.0), 4) == 0
				var point := Vector2(side * 11.5, BAY.position.y + 5 + i * 7.5)
				draw_circle(point, 1.0, Color(1.8, 0.8, 0.35, opening) if lit else Color(0.5, 0.25, 0.3, opening))
		# Elevator platform with launch chevrons.
		var lift := Rect2(-9, -9, 18, 22)
		draw_rect(lift, Color(0.12, 0.06, 0.1, opening))
		draw_rect(lift, Color(0.7, 0.3, 0.4, opening * 0.8), false, 1.0)
		for i in 2:
			var y := 6.0 + i * 4.0
			draw_polyline(PackedVector2Array([Vector2(-5, y - 2), Vector2(0, y + 1), Vector2(5, y - 2)]), Color(1.0, 0.55, 0.25, opening * 0.6), 1.0)
		_draw_waiting_aircraft(opening)
	# Pocket blast doors: each leaf shrinks into its wall as it opens.
	var leaf := BAY.size.x * 0.5 * (1.0 - opening)
	for side in [-1.0, 1.0]:
		if leaf < 0.5: continue
		var outer: float = side * BAY.size.x * 0.5
		var inner: float = outer - side * leaf
		var door := Rect2(minf(outer, inner), BAY.position.y, absf(outer - inner), BAY.size.y)
		draw_rect(door, Color(0.14, 0.065, 0.1) if alive else Color(0.08, 0.04, 0.06))
		draw_rect(door, Color(0.62, 0.26, 0.38), false, 1.0)
		for y in [BAY.position.y + 15.0, BAY.position.y + 30.0, BAY.position.y + 45.0]:
			draw_line(Vector2(door.position.x + 1, y), Vector2(door.end.x - 1, y), Color(0.35, 0.16, 0.24), 1.0)
		# Hazard stripes on the leading edge.
		var stripe_x: float = inner + side * 3.0
		for i in 8:
			var y0 := BAY.position.y + 2.0 + i * 7.5
			var stripe := PackedVector2Array([Vector2(stripe_x - 1.5, y0), Vector2(stripe_x + 1.5, y0 + 2.5), Vector2(stripe_x + 1.5, y0 + 5.0), Vector2(stripe_x - 1.5, y0 + 2.5)])
			draw_colored_polygon(stripe, Color(1.0, 0.6, 0.15, 0.35 + 0.5 * alert) if alive else Color(0.3, 0.2, 0.1))
	if alive and (opening > 0.0 and opening < 0.35 or slam_flash > 0):
		# Light leaks through the seam as it cracks open or slams shut.
		var leak := maxf(1.0 - opening / 0.35, slam_flash / 0.15) if opening > 0 else slam_flash / 0.15
		draw_line(Vector2(0, BAY.position.y), Vector2(0, BAY.end.y), Color(2.0, 1.1, 0.7, leak), 1.5)
	# Exit rails beyond the mouth, lit toward the player during a sortie.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 10, BAY.end.y), Vector2(side * 10, 57), Color("5e3446"), 1.0)
		for i in 3:
			var lit := active and alive and alert > 0 and posmod(i - int(age * 8.0), 3) == 0
			draw_line(Vector2(side * 12, 38 + i * 7), Vector2(side * 8, 38 + i * 7), Color(1.5, 0.65, 0.25) if lit else Color("643849"), 1.5)
	if launch_charge > 0 and active:
		# Striker sorties light the catapult rail yellow before launch.
		var rail := Color(1.0, 0.7, 0.2) if upcoming_kind() == 1 else Color(1.0, 0.38, 0.12)
		draw_line(Vector2(0, BAY.end.y - 4), Vector2(0, 57), Color(rail, launch_charge * 0.5), 2.0)
	if launch_flash > 0:
		draw_circle(Vector2(0, BAY.end.y), 6.0 * launch_flash / 0.5, Color(2.0, 1.2, 0.7, launch_flash))

func _draw_waiting_aircraft(opening: float) -> void:
	# After the last departure the bay stays empty while the doors close.
	if not active or health <= 0 or (launch_remaining == 0 and (door_hold > 0 or door_close_left > 0)): return
	var waiting := launch_remaining if launch_remaining > 0 else 3
	var striker := upcoming_kind() == 1
	var texture: Texture2D = STRIKER_TEX if striker else FIGHTER_TEX
	var tint := Color(1.0, 0.78, 0.18) if striker else Color(1.0, 0.4, 0.08)
	var base := 0.32 if striker else 0.4
	var rise := lift_rise()
	# The next aircraft rides the lift up (grows and lights up); one more waits in shadow.
	if waiting > 1:
		_draw_aircraft(texture, Vector2(0, -19), base * 0.55, Color(tint * 0.35, opening * 0.7))
	var lit := tint.lerp(Color(1.4, 1.2, 1.1), 0.35 * rise) * lerpf(0.3, 1.0, rise)
	_draw_aircraft(texture, Vector2(0, 4), base * lerpf(0.6, 0.95, rise), Color(lit, opening))

func _draw_aircraft(texture: Texture2D, at: Vector2, scale_factor: float, color: Color) -> void:
	draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	draw_texture(texture, -texture.get_size() * 0.5, color)
	draw_set_transform(Vector2.ZERO)

## Rotating amber beacons on the bay roof, spun up during a sortie.
func _draw_hangar_beacons() -> void:
	var alert := bay_alert()
	if alert <= 0: return
	for side in [-1.0, 1.0]:
		var beacon := Vector2(side * 21, -33)
		var angle: float = age * 9.0 * side
		fx.draw_circle(beacon, 1.6, Color(2.2, 1.2, 0.3, alert))
		for arm in [0.0, PI]:
			var flare := Vector2.from_angle(angle + arm)
			fx.draw_line(beacon + flare * 1.5, beacon + flare * 7.0, Color(1.6, 0.8, 0.2, 0.45 * alert), 1.0, true)

## Local rect a part may occupy, including its barrel sweep and deck rails.
## Parts of the carrier are laid out so these never intersect.
func footprint() -> Rect2:
	match mode:
		TURRET, ESCORT: return Rect2(-20, -18, 40, 47)
		HANGAR: return Rect2(-34, -42, 68, 99)
		BRIDGE: return Rect2(-52, -50, 104, 108)
		ENGINE: return Rect2(-15, -15, 30, 30)
	return Rect2(-10, -10, 20, 20)

## Dark socket under each part hides hull lines that would cross its art.
func _draw_socket() -> void:
	var outline := Color("4a2334")
	match mode:
		HANGAR:
			var pad := PackedVector2Array([Vector2(-26,-42),Vector2(26,-42),Vector2(34,-32),Vector2(34,32),Vector2(26,42),Vector2(-26,42),Vector2(-34,32),Vector2(-34,-32),Vector2(-26,-42)])
			draw_colored_polygon(pad, Color("0a0710"))
			draw_polyline(pad, outline, 1.0, true)
		BRIDGE:
			var hexagon := PackedVector2Array()
			for i in 7: hexagon.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * 52.0)
			draw_colored_polygon(hexagon, Color("0a0710"))
			draw_polyline(hexagon, outline, 1.0, true)
		ENGINE:
			draw_rect(Rect2(-15,-15,30,30), Color("0b0610"))
			draw_rect(Rect2(-15,-15,30,30), outline, false, 1.0)

func _draw() -> void:
	_draw_socket()
	if mode in [TURRET, BRIDGE, ESCORT]:
		if mode != BRIDGE:
			# Angular fixed bearing plates make rotation readable without an HP ring.
			var plate := PackedVector2Array([Vector2(-16,-12),Vector2(-10,-18),Vector2(10,-18),Vector2(16,-12),Vector2(16,13),Vector2(10,18),Vector2(-10,18),Vector2(-16,13),Vector2(-16,-12)])
			draw_colored_polygon(plate, Color("180e20"))
			draw_polyline(plate, Color("77354f"), 1.0, true)
			for side in [-1,1]:
				draw_line(Vector2(side*18,-8), Vector2(side*18,8), Color("bd566a"), 1.0)
		if warning and cooldown <= LOCK_TIME and current_variant != 3:
			var start := muzzle.position.rotated(pivot.rotation)
			draw_line(start, start + Vector2.DOWN.rotated(pivot.rotation)*46, Color(1.0,0.3,0.35,0.4), 0.6, true)
	elif mode == HANGAR:
		_draw_hangar_bay()
