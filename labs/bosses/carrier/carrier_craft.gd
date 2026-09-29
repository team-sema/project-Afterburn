extends Node2D
## Carrier aircraft outside the shared boss HP: hangar fighters, catapult
## strikers and transit raiders. No run rewards or Enemy lifecycle.
signal destroyed

enum Kind { FIGHTER, STRIKER, RAIDER }
const Neon = preload("res://labs/bosses/carrier/carrier_neon_visual.gd")
const Playfield := preload("res://menus/playfield_layout.gd")
const RAIL_LOCK := 0.55
const STRIKER_SPEED := 280.0
const RAIDER_SPEED := 260.0
var kind := Kind.FIGHTER
var maximum := 20
var health := 20
var active := false
var age := 0.0
var hit_flash := 0.0
var world: Node2D
var target: Node2D
var hurtbox: HurtboxComponent
var ram: HitboxComponent
var barrage: BarragePlayer
var visual: Node2D
var muzzle: Node2D
var warning := false
var fired := false
var formation_slot := 1
var firing_side := 1.0
var flight_origin := Vector2.ZERO
## Raiders start at the hull speed of the hatch they leave, then accelerate.
var launch_speed := 0.0

func energy() -> Color:
	return [Color(1.0, 0.4, 0.08), Color(1.0, 0.78, 0.18), Color(1.0, 0.25, 0.5)][kind]

func _ready() -> void:
	add_to_group("carrier_craft")
	z_index = 3
	health = maximum
	flight_origin = position
	var texture: Texture2D = preload("res://assets/enemies/enemy_interceptor.svg")
	if kind == Kind.STRIKER: texture = preload("res://assets/enemies/enemy_striker.svg")
	visual = Neon.make(texture, 0.4 if kind != Kind.STRIKER else 0.32, energy())
	add_child(visual)
	muzzle = Node2D.new()
	muzzle.position.y = 12
	add_child(muzzle)
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 20)
	shape.shape = rectangle
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hurt.connect(func(hit: HitboxComponent): take_damage(hit.damage))
	if kind == Kind.STRIKER:
		# Strikers are the projectile: the hull itself rams along the rail.
		ram = HitboxComponent.new()
		ram.collision_layer = 0
		ram.collision_mask = 1
		var ram_shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 7
		ram_shape.shape = circle
		ram.add_child(ram_shape)
		add_child(ram)
	barrage = BarragePlayer.new()
	add_child(barrage)
	set_active(active)

func set_active(value: bool) -> void:
	active = value and health > 0
	hurtbox.is_invincible = not active
	if not active:
		barrage.stop()
		if ram != null: ram.get_child(0).set_deferred("disabled", true)

func take_damage(amount: int) -> void:
	if not active or health <= 0: return
	health -= mini(health, maxi(amount, 0))
	hit_flash = 0.1
	if health == 0:
		set_active(false)
		preload("res://labs/bosses/carrier/carrier_destruction_effect.gd").spawn(world, global_position, 10.0)
		destroyed.emit()

func _physics_process(delta: float) -> void:
	hit_flash = maxf(0, hit_flash - delta)
	if active:
		age += delta
		match kind:
			Kind.FIGHTER: _fly_fighter(delta)
			Kind.STRIKER: _fly_striker(delta)
			Kind.RAIDER: _fly_raider(delta)
	visual.get_node("Core").self_modulate = Color.WHITE if hit_flash > 0 else Color(1.0, 0.91, 0.95)
	visual.get_node("TightGlow").self_modulate = Color(energy(), 0.55 + (0.35 if warning else 0.0))
	queue_redraw()
	if position.y > 420: queue_free()

func _fly_fighter(delta: float) -> void:
	var velocity := Vector2(0, lerpf(24, 78, clampf(age / 0.65, 0, 1)))
	if age > 0.65:
		var lane := clampf(flight_origin.x + (formation_slot - 1) * 34 + firing_side * 12, 18, Playfield.SIZE.x - 18)
		velocity.x = clampf((lane - position.x) * 2.5, -65, 65)
	position += velocity * delta
	visual.rotation = lerp_angle(visual.rotation, Vector2.DOWN.angle_to(velocity), delta * 5)
	warning = age > 0.8 and not fired
	if age >= 1.3 and not fired: _fire(3)

func _fly_striker(delta: float) -> void:
	# Hold on the catapult while the rail line is shown, then dash straight.
	warning = age < RAIL_LOCK
	if age >= RAIL_LOCK:
		position.y += STRIKER_SPEED * delta
	else:
		position.y += 10 * delta

func _fly_raider(delta: float) -> void:
	# Strafing dive faster than the hull's transit (peak ~257px/s) so raiders
	# visibly outrun the carrier instead of drifting back over its deck.
	var boost := clampf(age / 0.4, 0.0, 1.0)
	var velocity := Vector2(firing_side * -30 * boost, lerpf(launch_speed, RAIDER_SPEED, boost))
	position += velocity * delta
	visual.rotation = Vector2.DOWN.angle_to(velocity)
	warning = age > 0.15 and not fired
	if age >= 0.35 and not fired: _fire(7)

func _fire(pattern_mode: int) -> void:
	fired = true
	warning = false
	var sequence := preload("res://patterns/carrier_lab_pattern.gd").new()
	sequence.build({"mode": pattern_mode})
	barrage.play(sequence, muzzle, world, target)

func _draw() -> void:
	if not active: return
	var exhaust := 10.0 + 8.0 * absf(sin(age * 28))
	if kind == Kind.STRIKER and age >= RAIL_LOCK: exhaust *= 2.2
	if kind == Kind.RAIDER: exhaust *= 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -6), Vector2(0, -exhaust), Vector2(3, -6)]), Color(energy(), 0.65))
	if kind == Kind.STRIKER and warning:
		# Catapult rail: the exact lane the striker will occupy.
		var progress := age / RAIL_LOCK
		draw_line(Vector2(0, 10), Vector2(0, 420), Color(1.0, 0.7, 0.2, 0.15 + 0.4 * progress), 1.0 + progress * 2.0)
