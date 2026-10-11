extends Node2D
## Eight physical mounts; only the aligned lower pair can fight.
signal health_changed(current: int, maximum: int)
const Turret = preload("res://enemies/octagon/octagon_turret.gd")
const RADIUS := 240.0
const STEP := PI / 4.0
const OPEN_TIME := 0.55
const FIGHT_TIME := 4.5
const CLOSE_TIME := 0.45
const TURN_TIME := 1.8
enum { OPENING, FIGHTING, CLOSING, TURNING, DEFEATED }
var world: Node2D
var parts: Array[Node2D] = []
var rotor: Node2D
var pair_index := 0
var state := OPENING
var age := 0.0
var start_angle := 0.0
var end_angle := 0.0
var turn_duration := TURN_TIME
var maximum := Turret.MAX_HP * 8
var health := maximum
var defeated := false

func _ready() -> void:
	position = Vector2(150,-132)
	rotor = Node2D.new()
	add_child(rotor)
	var hull := Sprite2D.new()
	hull.texture = preload("res://assets/enemies/octagon_ring.svg")
	hull.scale = Vector2.ONE * 0.5
	rotor.add_child(hull)
	for i in 8:
		var part := Turret.new()
		var angle := PI / 2.0 - STEP / 2.0 + i * STEP
		part.position = Vector2.from_angle(angle) * RADIUS
		part.rotation = angle - PI / 2.0
		part.world = world
		part.damaged.connect(_on_damage)
		rotor.add_child(part)
		parts.append(part)

func active_indices() -> Array[int]:
	return [pair_index, (pair_index+1)%8]

func _on_damage(amount: int) -> void:
	health -= amount
	health_changed.emit(health, maximum)
	if health <= 0:
		defeated = true
		state = DEFEATED
		for part in parts: part.set_active(false)
		for bullet in EnemyBullets.get_all(world):
			bullet.queue_free()

func next_pair() -> void:
	if defeated or state in [CLOSING, TURNING]: return
	for part in parts: part.set_active(false)
	state = CLOSING
	# Closing starts from the current partial opening as well.
	age = CLOSE_TIME * (1.0 - parts[pair_index].opening)

func _begin_turn() -> void:
	start_angle = rotor.rotation
	var steps := 1
	while steps < 8:
		var candidate := (pair_index+steps)%8
		if parts[candidate].health > 0 or parts[(candidate+1)%8].health > 0: break
		steps += 1
	pair_index = (pair_index+steps)%8
	end_angle = start_angle - STEP * steps
	turn_duration = TURN_TIME + (steps-1)*0.25
	age = 0
	state = TURNING

func _process(delta: float) -> void:
	if defeated: return
	age += delta
	match state:
		OPENING:
			for i in active_indices(): parts[i].opening = minf(age / OPEN_TIME,1.0)
			if age >= OPEN_TIME:
				state = FIGHTING
				age = 0
				parts[pair_index].set_active(true)
				parts[(pair_index+1)%8].set_active(true,0.45)
		FIGHTING:
			if age >= FIGHT_TIME: next_pair()
		CLOSING:
			for i in active_indices(): parts[i].opening = maxf(1.0-age/CLOSE_TIME,0.0)
			if age >= CLOSE_TIME: _begin_turn()
		TURNING:
			rotor.rotation = lerpf(start_angle,end_angle,smoothstep(0,1,minf(age/turn_duration,1)))
			if age >= turn_duration:
				rotor.rotation = end_angle
				state = OPENING
				age = 0

func status_text() -> String:
	if defeated: return "ALL MODULES DESTROYED"
	var phase: String = ["OPENING","ENGAGED","CLOSING","ROTATING"][state]
	return "%02d + %02d / %s" % [pair_index+1,(pair_index+1)%8+1,phase]
