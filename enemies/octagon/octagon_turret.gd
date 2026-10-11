extends Node2D
## One reusable test weapon. Remains mounted after destruction.
signal damaged(amount: int)
signal destroyed
const Neon = preload("res://enemies/carrier/carrier_neon_visual.gd")
const MAX_HP := 180
var health := MAX_HP
var active := false
var opening := 0.0
var cooldown := 0.0
var charging := false
var flash := 0.0
var world: Node2D
var hurtbox: HurtboxComponent
var visual: Node2D
var gun: Node2D
var shot: BarrageShot
var volleys := 0

func _ready() -> void:
	visual = Neon.make(preload("res://assets/enemies/octagon_turret.svg"), 0.5, Color(1,0.08,0.28))
	add_child(visual)
	gun = Neon.make(preload("res://assets/enemies/carrier_gun.svg"),0.4,Color(1,0.08,0.28))
	gun.position.y = 7
	add_child(gun)
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(48,60)
	shape.shape = rectangle
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hurt.connect(func(hit: HitboxComponent): take_damage(hit.damage))
	hurtbox.is_invincible = true
	shot = BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/round.tres")
	shot.behavior = BulletBehavior.new()

func set_active(value: bool, delay := 0.0) -> void:
	active = value and health > 0
	hurtbox.is_invincible = not active
	cooldown = delay
	charging = false

func take_damage(amount: int) -> void:
	if not active or health <= 0 or amount <= 0: return
	var applied := mini(health, amount)
	health -= applied
	flash = 0.1
	damaged.emit(applied)
	if health == 0:
		set_active(false)
		preload("res://enemies/carrier/carrier_destruction_effect.gd").spawn(world, global_position, 30, false)
		destroyed.emit()
	queue_redraw()

func _process(delta: float) -> void:
	flash = maxf(0, flash - delta)
	if active:
		cooldown -= delta
		if cooldown <= 0:
			if charging:
				fire()
				charging = false
				cooldown = 0.9
			else:
				charging = true
				cooldown = 0.65
	var tint := Color("f3b2c5") if active else Color("7d364d")
	if health == 0: tint = Color("302335")
	if flash > 0: tint = Color.WHITE
	visual.get_node("Core").self_modulate = tint
	visual.get_node("WideGlow").visible = health > 0
	visual.get_node("TightGlow").visible = health > 0
	gun.visible = health > 0 and opening > 0.5
	gun.rotation = -global_rotation
	gun.get_node("Core").self_modulate = tint
	queue_redraw()

func fire() -> void:
	if not active or health <= 0: return
	for angle in [-12.0, 0.0, 12.0]:
		shot.spawn(world, gun.to_global(Vector2(0,20.8)), Vector2.DOWN.rotated(deg_to_rad(angle)), 85)
	volleys += 1
	flash = 0.08

func _draw() -> void:
	# A dark continuous backing keeps the separate SVG blades readable.
	draw_colored_polygon(PackedVector2Array([Vector2(-20,-37),Vector2(20,-37),Vector2(32,-17),Vector2(30,22),Vector2(16,40),Vector2(-16,40),Vector2(-30,22),Vector2(-32,-17)]), Color("130e1e"))
	if health <= 0:
		draw_line(Vector2(-12,-14),Vector2(11,15),Color("8b3846"),2)
		draw_line(Vector2(8,-9),Vector2(-10,13),Color("593647"),2)
		return
	# Split shutters cover the bore while travelling, withdraw sideways to open.
	var gap := opening * 11.0
	for side in [-1,1]:
		var x: float = side * (5.5 + gap)
		draw_rect(Rect2(x-5.5,-13,11,27),Color("3b1b2d"))
		draw_line(Vector2(x,-11),Vector2(x,12),Color("ce5676"),1)
	if opening > 0.5:
		var strength := clampf(1.0 - cooldown / 0.65,0,1) if charging else 0.0
		draw_circle(Vector2.ZERO,3 + strength*3,Color(1.4,0.5+strength*0.5,0.7+strength*0.3))
