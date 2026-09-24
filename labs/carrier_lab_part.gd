extends Node2D
## Independent destructible carrier hardware; no run rewards or Enemy lifecycle.
signal damaged(amount: int)
signal destroyed
signal launch_requested(slot: int)

const Neon = preload("res://labs/carrier_neon_visual.gd")
var maximum := 120
var health := 120
var mode := 0
var section := 0
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
var recoil := 0.0
var gun_scale := 0.36
var launch_charge := 0.0
var launch_flash := 0.0
var launch_clock := 2.0
var launch_remaining := 0
var launch_gap := 0.0
var doors: Array[Polygon2D] = []
var formation_slot := 1
var flight_origin := Vector2.ZERO
var fighter_fired := false

func destruction_radius() -> float:
	match mode:
		1: return 40.0
		2: return 54.0
		3: return 10.0
		4: return 16.0
	return 21.0

func _ready() -> void:
	health = maximum
	var texture: Texture2D = preload("res://assets/svg/carrier_turret.svg")
	var visual_scale := 0.25
	if mode == 1:
		texture = preload("res://assets/svg/carrier_hangar.svg")
		visual_scale = 0.65
	elif mode == 2:
		texture = preload("res://assets/svg/enemy_elite_fighter.svg")
		visual_scale = 0.72
	elif mode == 3:
		texture = preload("res://assets/svg/enemy_interceptor.svg")
		visual_scale = 0.4
		flight_origin = position
	visual = Neon.make(texture, visual_scale, Color(1.0, 0.08, 0.26) if mode != 3 else Color(1.0, 0.4, 0.08))
	add_child(visual)
	if mode == 1:
		for side in [-1, 1]:
			var door := Polygon2D.new()
			door.polygon = PackedVector2Array([Vector2(0,-22),Vector2(side*8,-16),Vector2(side*8,26),Vector2(0,32)])
			visual.add_child(door)
			doors.append(door)
	if mode in [0, 2, 4]:
		pivot = Node2D.new()
		add_child(pivot)
		gun_scale = 0.52 if mode == 2 else 0.36
		gun = Neon.make(preload("res://assets/svg/carrier_gun.svg"), gun_scale, Color(1.0,0.12,0.3))
		pivot.add_child(gun)
		muzzle = Node2D.new()
		muzzle.position.y = 52 * gun_scale
		pivot.add_child(muzzle)
	else:
		muzzle = Node2D.new()
		muzzle.position.y = 12 if mode == 3 else 30
		add_child(muzzle)
	muzzle_flash = Polygon2D.new()
	muzzle_flash.polygon = PackedVector2Array([Vector2(-4,0),Vector2(-2,7),Vector2(0,13),Vector2(2,7),Vector2(4,0)])
	muzzle_flash.color = Color(2.0,1.1,0.7)
	muzzle.add_child(muzzle_flash)
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20,20) if mode == 3 else (Vector2(22,24) if mode in [0,4] else (Vector2(54,72) if mode == 1 else Vector2(42,38)))
	shape.shape = rectangle
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hurt.connect(func(hit: HitboxComponent): take_damage(hit.damage))
	barrage = BarragePlayer.new()
	add_child(barrage)
	barrage.finished.connect(func(): cooldown = 1.8 if mode != 2 else 2.0)
	barrage.volley_fired.connect(func(_projectiles): recoil = 1.0)
	set_active(active)

func set_active(value: bool) -> void:
	active = value and health > 0
	if hurtbox != null: hurtbox.is_invincible = not active
	if not active:
		if barrage != null: barrage.stop()
		launch_remaining = 0
		launch_charge = 0
		recoil = 0
	warning = false
	_update_visual()
	queue_redraw()

func take_damage(amount: int) -> void:
	if not active or health <= 0: return
	var applied := mini(health, maxi(amount, 0))
	if applied == 0: return
	health -= applied
	hit_flash = 0.12
	damaged.emit(applied)
	if health == 0:
		set_active(false)
		preload("res://labs/carrier_destruction_effect.gd").spawn(world, global_position, destruction_radius(), mode in [1,2])
		destroyed.emit()
	queue_redraw()

func _physics_process(delta: float) -> void:
	hit_flash = maxf(0, hit_flash - delta)
	launch_flash = maxf(0, launch_flash - delta)
	recoil = move_toward(recoil, 0, delta * 7)
	if active:
		age += delta
		if mode == 1:
			_process_hangar(delta)
		elif mode == 3:
			_process_fighter(delta)
		else:
			_process_weapon(delta)
	_update_visual()
	queue_redraw()

func _process_hangar(delta: float) -> void:
	launch_clock -= delta
	if launch_clock <= 0:
		launch_clock += 6.0
		launch_remaining = 3
		launch_gap = 0
	if launch_remaining > 0:
		launch_gap -= delta
		if launch_gap <= 0:
			launch_requested.emit(3 - launch_remaining)
			launch_remaining -= 1
			launch_gap = 0.35
	launch_charge = 1.0 if launch_remaining > 0 else clampf(1.0 - launch_clock, 0.0, 1.0)

func _process_fighter(delta: float) -> void:
	var velocity := Vector2(0, lerpf(24, 78, clampf(age / 0.65, 0, 1)))
	if age > 0.65:
		var lane := clampf(flight_origin.x + (formation_slot - 1) * 34 + firing_side * 12, 18, 222)
		velocity.x = clampf((lane - position.x) * 2.5, -65, 65)
	position += velocity * delta
	visual.rotation = lerp_angle(visual.rotation, Vector2.DOWN.angle_to(velocity), delta * 5)
	warning = age > 0.8 and not fighter_fired
	if age >= 1.3 and not fighter_fired:
		fighter_fired = true
		warning = false
		var sequence := preload("res://patterns/carrier_lab_pattern.gd").new()
		sequence.build({"mode": 3})
		barrage.play(sequence, muzzle, world, target)
	if position.y > 400: queue_free()

func _process_weapon(delta: float) -> void:
	# The final 0.25 seconds and the aimed burst preserve the visible lock.
	if barrage.running and current_variant == 2:
		pivot.rotation = clampf(pivot.rotation + firing_side * deg_to_rad(58) * delta, -deg_to_rad(70), deg_to_rad(70))
	elif not barrage.running and not (warning and cooldown <= 0.25):
		var desired := 0.0
		if is_instance_valid(target):
			desired = clampf(Vector2.DOWN.angle_to(target.global_position - global_position), -deg_to_rad(70), deg_to_rad(70))
		if warning and current_variant == 0: desired = firing_side * deg_to_rad(9)
		if warning and current_variant == 2: desired = -firing_side * deg_to_rad(32)
		pivot.rotation = rotate_toward(pivot.rotation, desired, deg_to_rad(100) * delta)
	if barrage.running: return
	cooldown -= delta
	if cooldown > 0: return
	if not warning:
		if not fire_permission: return
		current_variant = (pattern_index + attack_cycle) % 3
		if mode == 4: current_variant = 1
		warning = true
		cooldown = 0.95
	else:
		warning = false
		var sequence := preload("res://patterns/carrier_lab_pattern.gd").new()
		sequence.build({"mode": mode, "variant": current_variant})
		attack_cycle += 1
		barrage.play(sequence, muzzle, world, target)

func _update_visual() -> void:
	if visual == null: return
	var energy := Color(1.0,0.08,0.26) if mode != 3 else Color(1.0,0.4,0.08)
	var charge := clampf(1.0 - cooldown / 0.95, 0, 1) if warning else 0.0
	if mode == 1: charge = maxf(launch_charge, launch_flash * 2)
	visual.get_node("WideGlow").self_modulate = Color(energy,0.22 + charge * 0.2)
	visual.get_node("TightGlow").self_modulate = Color(energy,0.55 + charge * 0.35)
	visual.get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else Color(1.0,0.91,0.95)
	visual.modulate = Color.WHITE if health > 0 else Color(0.16,0.1,0.16,0.5)
	if gun != null:
		visual.get_node("Core").self_modulate = Color(0.55,0.28,0.38) if hit_flash <= 0 else Color.WHITE
		gun.position.y = 16 * gun_scale - recoil * 3.5
		gun.modulate = visual.modulate
		gun.get_node("Core").self_modulate = Color(1.0 + charge,0.9 + charge * 0.3,0.95)
		gun.get_node("TightGlow").self_modulate = Color(energy,0.65 + charge * 0.35)
		# The muzzle follows the physical recoil as well as the barrel angle.
		muzzle.position.y = 52 * gun_scale - recoil * 3.5
	muzzle_flash.visible = health > 0 and recoil > 0.2
	muzzle_flash.scale = Vector2.ONE * recoil
	if mode == 1:
		var opening := maxf(launch_charge, launch_flash * 2.0) if health > 0 and active else 0.0
		for i in doors.size():
			doors[i].position.x = (-1 if i == 0 else 1) * opening * 10.0
			doors[i].color = Color(1.0,0.8,0.75) if opening > 0 else Color(0.65,0.3,0.4)
			doors[i].visible = health > 0
		var integrity := float(health) / maximum
		visual.get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else Color(1.0,0.91,0.95).lerp(Color(0.65,0.35,0.45), 1.0 - integrity)
	visual.scale = Vector2.ONE * (1.06 if hit_flash > 0 else 1.0)

func _draw() -> void:
	if mode in [0, 2, 4]:
		# Angular fixed bearing plates make rotation readable without an HP ring.
		var plate := PackedVector2Array([Vector2(-16,-12),Vector2(-10,-18),Vector2(10,-18),Vector2(16,-12),Vector2(16,13),Vector2(10,18),Vector2(-10,18),Vector2(-16,13),Vector2(-16,-12)])
		draw_colored_polygon(plate, Color("180e20"))
		draw_polyline(plate, Color("77354f"), 1.0, true)
		for side in [-1,1]:
			draw_line(Vector2(side*18,-8), Vector2(side*18,8), Color("bd566a"), 1.0)
		if warning and cooldown <= 0.25:
			var start := muzzle.position.rotated(pivot.rotation)
			draw_line(start, start + Vector2.DOWN.rotated(pivot.rotation)*46, Color(1.0,0.3,0.35,0.4), 0.6, true)
	elif mode == 1:
		draw_rect(Rect2(-17,-28,34,64), Color("050711"))
		for side in [-1,1]:
			draw_line(Vector2(side*20,28),Vector2(side*20,74),Color("5e3446"),1.0)
			for i in 5:
				var lit := active and health > 0 and posmod(i - int(age*6),5) == 0
				draw_line(Vector2(side*17,32+i*8),Vector2(side*13,32+i*8),Color(1.5,0.65,0.25) if lit else Color("643849"),1.5)
		if launch_charge > 0 and active:
			draw_line(Vector2(0,8),Vector2(0,68),Color(1.0,0.38,0.12,launch_charge*0.5),2.0)
	elif mode == 3 and active:
		var exhaust := 10.0 + 8.0 * absf(sin(age*28))
		draw_colored_polygon(PackedVector2Array([Vector2(-3,-6),Vector2(0,-exhaust),Vector2(3,-6)]),Color(1.0,0.4,0.1,0.65))
