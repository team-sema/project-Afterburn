extends Node2D
## Destructible RECYCLER hardware: bulkhead armor cover, cutter optic and control link.
## The control core uses the same visual stack for the shutdown reveal only. No run rewards or Enemy lifecycle.
signal damaged(amount: int)
signal destroyed

enum Mode { COVER, OPTIC, LINK, CORE }
const Neon = preload("res://labs/bosses/wall/wall_visual.gd")
const Debris = preload("res://labs/bosses/wall/wall_debris.gd")
## Structure color: the armor and machinery the core drives.
const STRUCTURE := Neon.STRUCTURE
## Control-system color: everything that carries the core's commands.
const SIGNAL := Color(1.0, 0.16, 0.2)
## COVER: HP ratios where a bolt lets go.
const SHED_RATIOS := [0.67, 0.34]

var mode := Mode.COVER
var maximum := 120
var health := 120
var active := false
var hit_flash := 0.0
var age := 0.0
## OPTIC/CORE: facing in radians, 0 = down.
var aim_angle := 0.0
## OPTIC/CORE: 0..1 charge before a shot; the core's scanner races with it.
var charge := 0.0
## COVER: 0 intact, 1 one bolt gone, 2 hanging by the last bolt.
var damage_stage := 0
var jolt := 0.0
var world: Node2D
var visual: Node2D
var hurtbox: HurtboxComponent
var muzzle: Node2D


func destruction_radius() -> float:
	match mode:
		Mode.COVER: return 24.0
		Mode.OPTIC: return 16.0
		Mode.LINK: return 14.0
	return 30.0


func energy() -> Color:
	return STRUCTURE if mode == Mode.COVER else SIGNAL


func _ready() -> void:
	health = maximum
	var texture: Texture2D
	var shape := CollisionShape2D.new()
	match mode:
		Mode.COVER:
			texture = preload("res://assets/enemies/wall_plate.svg")
			shape.shape = _rect(Vector2(22, 28))
		Mode.OPTIC:
			texture = preload("res://assets/enemies/wall_optic.svg")
			var circle := CircleShape2D.new()
			circle.radius = 9.0
			shape.shape = circle
		Mode.LINK:
			texture = preload("res://assets/enemies/wall_link.svg")
			shape.shape = _rect(Vector2(16, 20))
		Mode.CORE:
			texture = preload("res://assets/enemies/wall_core.svg")
			shape.shape = _rect(Vector2(16, 26))
	visual = Neon.make(texture, 0.5, energy())
	# Runtime details (iris, scanner) draw over the artwork.
	visual.show_behind_parent = true
	add_child(visual)
	muzzle = Node2D.new()
	add_child(muzzle)
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hurt.connect(func(hit: HitboxComponent): take_damage(hit.damage))
	set_active(active)


func _rect(size: Vector2) -> RectangleShape2D:
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	return rectangle


func set_active(value: bool) -> void:
	active = value and health > 0
	# Inactive parts are out of play: shots pass them and only structure stops a round.
	if hurtbox != null: hurtbox.is_invincible = not active
	_update_visual()
	queue_redraw()


func ratio() -> float:
	return float(health) / maxf(float(maximum), 1.0)


func take_damage(amount: int) -> void:
	if not active or health <= 0: return
	var applied := mini(health, maxi(amount, 0))
	if applied == 0: return
	health -= applied
	hit_flash = 0.1
	damaged.emit(applied)
	if mode == Mode.COVER and health > 0:
		while damage_stage < SHED_RATIOS.size() and ratio() <= SHED_RATIOS[damage_stage]:
			damage_stage += 1
			_shed()
	if health == 0:
		set_active(false)
		if mode != Mode.CORE:
			preload("res://labs/bosses/carrier/carrier_destruction_effect.gd").spawn(world, global_position, destruction_radius(), mode == Mode.COVER)
		destroyed.emit()
	queue_redraw()


## A bolt lets go: the cover jolts, cants a little further on its mount and throws sparks and a couple of chips.
func _shed() -> void:
	jolt = 1.0
	if world == null: return
	for i in 6:
		Debris.spawn(world, global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-10.0, 10.0)), Debris.Kind.SPARK, randf_range(4.0, 7.0))
	for i in 2:
		Debris.spawn(world, global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-8.0, 8.0)), Debris.Kind.PLATE, randf_range(2.5, 4.0))


func _physics_process(delta: float) -> void:
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	jolt = maxf(0.0, jolt - delta * 5.0)
	muzzle.position = Vector2.DOWN.rotated(aim_angle) * (12.0 if mode == Mode.OPTIC else 10.0)
	_update_visual()
	queue_redraw()


func _update_visual() -> void:
	if visual == null: return
	var alive := health > 0
	var lit := active and alive
	var pulse := 0.5 + 0.5 * sin(age * 6.0)
	var tone := energy()
	var glow_boost := 1.0
	match mode:
		Mode.COVER:
			# The emissive strip runs hotter as bolts give, and stutters on the last one.
			tone = STRUCTURE.lerp(SIGNAL, clampf((1.0 - ratio()) * 1.3, 0.0, 1.0))
			if damage_stage >= 2 and lit and int(age * 20.0) % 3 == 0:
				glow_boost = 0.35
			var lean := signf(position.x) if position.x != 0.0 else 1.0
			visual.rotation = lean * [0.0, 0.05, 0.12][damage_stage] + sin(age * 55.0) * 0.06 * jolt
			visual.position = Vector2(0, damage_stage * 1.0) + Vector2(sin(age * 71.0), cos(age * 63.0)) * 1.5 * jolt
		Mode.LINK:
			# Status lamps on the cartridge blink while it still carries commands.
			if lit and int(age * 3.0) % 2 == 1:
				glow_boost = 0.45
	visual.get_node("WideGlow").self_modulate = Color(tone, (0.16 + (0.22 + pulse * 0.16 + charge * 0.3 if lit else 0.0)) * glow_boost)
	visual.get_node("TightGlow").self_modulate = Color(tone, (0.4 + (0.45 + charge * 0.3 if lit else 0.0)) * glow_boost)
	var core := Color(0.96, 0.94, 1.0) if lit else tone * 0.4
	if mode == Mode.CORE: core = Color(0.8, 0.26, 0.3)
	# Hits flash the artwork past white so the bloom catches them.
	visual.get_node("Core").self_modulate = Color(1.6, 1.5, 1.4) if hit_flash > 0.0 else core
	visual.modulate = Color.WHITE if alive else Color(0.14, 0.1, 0.22, 0.55)
	visual.scale = Vector2.ONE * (1.05 if hit_flash > 0.0 else 1.0)


func _draw() -> void:
	match mode:
		Mode.OPTIC: _draw_iris()
		Mode.LINK: _draw_mount()
		Mode.CORE: _draw_scanner()


## Mechanical iris: blades open with the charge, the lens heats up, and the snout shows where the beam leaves.
func _draw_iris() -> void:
	if health <= 0: return
	var aperture := 1.6 + charge * 3.4
	draw_circle(Vector2.ZERO, 5.8, Color(0.04, 0.02, 0.02))
	for i in 6:
		var angle := TAU * i / 6.0 + age * 0.6 + charge * 1.2
		var blade := PackedVector2Array([
			Vector2.RIGHT.rotated(angle) * aperture,
			Vector2.RIGHT.rotated(angle + 0.9) * 5.8,
			Vector2.RIGHT.rotated(angle - 0.2) * 5.8,
		])
		draw_colored_polygon(blade, Color(0.85, 0.28, 0.3))
	draw_circle(Vector2.ZERO, aperture * 0.8, Color(2.0 + charge, 0.3, 0.3, 0.5 + charge * 0.5))
	var facing := Vector2.DOWN.rotated(aim_angle)
	draw_line(facing * 6.5, facing * 10.5, Color(1.0, 0.88, 0.84), 3.0)


## Neon clamp fixing the cartridge directly to the press underside.
func _draw_mount() -> void:
	Neon.line(self, Vector2(-4, -11), Vector2(4, -11), SIGNAL, 1.5, 0.65 if health > 0 else 0.12)


## Coffin module: a red scanner walks the slit, racing and flaring as the charge rises.
func _draw_scanner() -> void:
	if not visible: return
	var sweep := 0.5 + 0.5 * sin(age * (3.0 + charge * 14.0))
	var y := lerpf(-8.0, 6.0, sweep)
	draw_circle(Vector2(0, y), 2.5 + charge * 2.0, Color(1.8, 0.2, 0.25, 0.25 + charge * 0.3))
	draw_rect(Rect2(-1.2, y - 1.5, 2.4, 3.0), Color(2.6, 0.25 + charge * 0.6, 0.28))
