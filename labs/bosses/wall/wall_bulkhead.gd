extends Node2D
## Crusher bulkhead of the RECYCLER bay: an armored slab that breathes and lunges inward, cross-firing from casing vents.
## Breaking its armor cover tears the casing off and shows the rams, lead screws and gearing that really drive it.
signal lunge_landed

const Playfield = preload("res://menus/playfield_layout.gd")
const Neon = preload("res://labs/bosses/wall/wall_visual.gd")
const Part = preload("res://labs/bosses/wall/wall_part.gd")
const Beam = preload("res://labs/bosses/wall/wall_beam.gd")
const Pattern = preload("res://patterns/wall_lab_pattern.gd")
const STRUCTURE := Neon.STRUCTURE
const WIDTH := 72.0
const PARKED := -76.0
const VENT_Y := [150.0, 215.0, 280.0]
const RAM_Y := [118.0, 206.0, 300.0]
const SCREW_Y := [162.0, 254.0]
const OPTIC_Y := 104.0
## 02: how far the scan carriage stands out of the inner face.
const CARRIAGE_X := 12.0
## 01: seconds the armor cover stays open once its wall's lunge lands.
const COVER_OPEN := 6.0
## Once the casing is gone the exposed drive bay's face sits this far behind the slab line.
const BAY_FACE := 8.0
## Player shots may graze this far into the visible face before the armor stops them. The ship's outer gun
## fires flush with the wall when it hugs the face; without the margin that stream dies at the muzzle.
const SHOT_GRAZE := 4.0
const FIRE_PERIOD := 3.2
const FIRE_WARNING := 0.7

## -1 = left wall, 1 = right wall. Also the outward direction of the slab.
var side := -1
var jitter := 0.0
var inset := PARKED:
	set(value):
		inset = value
		position.x = (inset if side < 0 else float(Playfield.SIZE.x) - inset) + jitter
## Idle breathing: inset follows a slow sine around breathe_center while no move tween runs.
var breathing := false
var breathe_center := 30.0
var breathe_amplitude := 16.0
var breathe_period := 9.0
var breathe_t := 0.0
## True while the inner face travels toward the corridor.
var closing := false
## True while a telegraphed move (lunge slam, squeeze) drives the face inward. Only then does a push hurt;
## breathing and repositioning just shove the ship aside.
var crushing := false
## 01: the armor cover stays closed and only opens for COVER_OPEN seconds after this wall's lunge lands.
var cover_window := false
var cover_timer: Tween
var world: Node2D
var cover: Node2D
var optic: Node2D
var beam: Node2D
var armor: HurtboxComponent
var armor_shape: CollisionShape2D
var vents: Array[Node2D] = []
var barrages: Array[BarragePlayer] = []
var fire_enabled := false
var fire_clock := 0.0
var charging: Array[int] = []
var last_rest := -1
var corridor_width := 272.0
var warning := 0.0
var warning_duration := 0.0
var warning_left := 0.0
var casing_breached := false
## Lamp brightness; the control core powers the whole bay.
var power := 1.0
## Signed travel of the inner face; turns the lead screws and gears once they are exposed.
var drive_phase := 0.0
var optic_deploy := 0.0
var casing_visual: Node2D
var age := 0.0
var motion: Tween
var _last_inset := PARKED


func _ready() -> void:
	inset = inset
	_last_inset = inset
	var visual := Neon.make(preload("res://assets/enemies/wall_bulkhead.svg"), 0.5, STRUCTURE, preload("res://assets/enemies/wall_bulkhead_body.svg"))
	casing_visual = visual
	visual.position = Vector2(side * WIDTH * 0.5, 200)
	visual.scale.x = -1.0 if side > 0 else 1.0
	visual.show_behind_parent = true
	Neon.structure(visual, power)
	add_child(visual)
	armor = HurtboxComponent.new()
	armor.collision_layer = 2
	armor.collision_mask = 0
	armor.blocks_pierce = true
	armor_shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WIDTH, 400)
	armor_shape.shape = rectangle
	_place_armor()
	armor.add_child(armor_shape)
	add_child(armor)
	for y in VENT_Y:
		var vent := Node2D.new()
		vent.position = Vector2(-side * 2.0, y)
		add_child(vent)
		vents.append(vent)
		var barrage := BarragePlayer.new()
		add_child(barrage)
		barrages.append(barrage)
	cover = Part.new()
	cover.mode = Part.Mode.COVER
	cover.maximum = 150
	cover.world = world
	cover.position = Vector2(-side * 6.0, 80)
	add_child(cover)
	cover.destroyed.connect(_on_cover_destroyed)
	optic = Part.new()
	optic.mode = Part.Mode.OPTIC
	optic.maximum = 70
	optic.world = world
	optic.position = Vector2(-side * 8.0, OPTIC_Y)
	optic.visible = false
	add_child(optic)
	beam = Beam.new()
	beam.rotation = -side * PI * 0.5
	beam.visible = false
	add_child(beam)


func start_fire(first_delay: float) -> void:
	if casing_breached: return
	fire_enabled = true
	fire_clock = first_delay


func stop_fire() -> void:
	fire_enabled = false
	charging.clear()
	for barrage in barrages: barrage.stop()
	queue_redraw()


func begin_warning(duration: float) -> void:
	warning_duration = duration
	warning_left = duration


## `crush` marks a telegraphed squeeze: pushing the ship during it counts as a hit.
func move_to(target: float, duration: float, transition: Tween.TransitionType = Tween.TRANS_CUBIC, ease_type: Tween.EaseType = Tween.EASE_OUT, crush := false) -> Tween:
	warning_left = 0.0
	warning = 0.0
	if motion != null and motion.is_valid(): motion.kill()
	crushing = crush
	motion = create_tween()
	motion.tween_property(self, "inset", target, duration).set_trans(transition).set_ease(ease_type)
	motion.tween_callback(func(): crushing = false)
	return motion


## Telegraphed shove: guide lamps fill, the slab slams inward, holds, then eases back to its breathing band.
## With the cover window on, the landing opens the armor cover for COVER_OPEN seconds.
func lunge(target: float, warn := 0.9, hold := 0.8) -> void:
	begin_warning(warn)
	if motion != null and motion.is_valid(): motion.kill()
	crushing = false
	motion = create_tween()
	motion.tween_interval(warn)
	motion.tween_callback(func(): crushing = true)
	motion.tween_property(self, "inset", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_callback(_on_lunge_landed)
	motion.tween_interval(hold)
	motion.tween_property(self, "inset", breathe_center, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_lunge_landed() -> void:
	crushing = false
	lunge_landed.emit()
	if cover_window: open_cover()


## Opens the armor cover to fire for COVER_OPEN seconds (restarting any open window).
func open_cover() -> void:
	if cover_timer != null and cover_timer.is_valid(): cover_timer.kill()
	cover.set_active(true)
	cover_timer = create_tween()
	cover_timer.tween_interval(COVER_OPEN)
	cover_timer.tween_callback(cover.set_active.bind(false))


## Closed, the cover is out of play like any inactive part: dim, no damage, shots pass it.
func seal_cover() -> void:
	if cover_timer != null and cover_timer.is_valid(): cover_timer.kill()
	cover.set_active(false)


func is_moving() -> bool:
	return motion != null and motion.is_valid() and motion.is_running()


func face_x() -> float:
	return position.x


## World x measured `distance` px inward from this wall's own screen edge.
func _edge_world(distance: float) -> float:
	return distance if side < 0 else float(Playfield.SIZE.x) - distance


func _local_x(world_x: float) -> float:
	return to_local(Vector2(world_x, 0)).x


func _on_cover_destroyed() -> void:
	# The casing goes with the cover; the vents it housed die with it.
	casing_breached = true
	casing_visual.visible = false
	cover.visible = false
	# Shots now stop at the drive bay's face, not the missing casing line.
	_place_armor()
	stop_fire()
	queue_redraw()


## Shot-stopping armor runs from the visible face (casing line, or the drive bay once breached) outward,
## less the graze margin.
func _place_armor() -> void:
	var face := BAY_FACE if casing_breached else 0.0
	armor_shape.position = Vector2(side * (WIDTH * 0.5 + face + SHOT_GRAZE), 200)


## The defense optic unfolds out of the exposed drive bay onto the inner face. It then rides the wall as a
## scan carriage, so it sits far enough out that the ship can line up under it without hugging the face.
func deploy_optic(duration: float) -> void:
	optic.visible = true
	optic.position = Vector2(side * 14.0, OPTIC_Y)
	var unfold := create_tween()
	unfold.tween_property(optic, "position:x", -side * CARRIAGE_X, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unfold.parallel().tween_property(self, "optic_deploy", 1.0, duration)


func _physics_process(delta: float) -> void:
	age += delta
	if warning_left > 0.0:
		warning_left = maxf(0.0, warning_left - delta)
		warning = 1.0 - warning_left / maxf(warning_duration, 0.01)
	if breathing and not is_moving():
		breathe_t += delta
		inset = breathe_center + breathe_amplitude * sin(breathe_t * TAU / breathe_period)
	var travel := inset - _last_inset
	closing = travel > 0.01
	Neon.structure(casing_visual, power, warning * 0.5)
	drive_phase += travel
	_last_inset = inset
	if fire_enabled:
		fire_clock -= delta
		if fire_clock <= FIRE_WARNING and charging.is_empty():
			charging = _pick_vents()
		if fire_clock <= 0.0:
			_fire_charged()
			fire_clock += FIRE_PERIOD
	queue_redraw()


func _pick_vents() -> Array[int]:
	var rest_options: Array[int] = []
	for i in VENT_Y.size():
		if i != last_rest: rest_options.append(i)
	last_rest = rest_options.pick_random()
	var picked: Array[int] = []
	for i in VENT_Y.size():
		if i != last_rest: picked.append(i)
	return picked


func _fire_charged() -> void:
	var lifetime := maxf(corridor_width, 20.0) / (75.0 * 0.97)
	for i in charging:
		var sequence := Pattern.new()
		sequence.build({"kind": "crossfire", "angle": 90.0 * side, "lifetime": lifetime})
		barrages[i].play(sequence, vents[i], world)
	charging.clear()


func _draw() -> void:
	if casing_breached:
		_draw_drive_bay()
	else:
		_draw_way_cover()
		_draw_vents()
	_draw_guide_lamps()
	if optic.visible:
		_draw_optic_arm()


## Pleated support behind the armor, drawn as separated neon ribs.
func _draw_way_cover() -> void:
	var back := side * WIDTH
	var edge := _local_x(_edge_world(-4.0))
	if (edge - back) * side <= 0.0: return
	draw_rect(Rect2(minf(edge, back), 60, absf(edge - back), 340), Color(0.028, 0.02, 0.05))
	var folds := maxi(3, int(absf(edge - back) / 9.0))
	for i in folds + 1:
		var x := lerpf(back, edge, float(i) / folds)
		Neon.line(self, Vector2(x, 60), Vector2(x, 400), STRUCTURE, 1.0, 0.18)
	for y in [70.0, 390.0]:
		Neon.line(self, Vector2(back, y), Vector2(edge, y), STRUCTURE, 1.2, 0.4)


## The same violet geometry continues inside: luminous shafts in an open frame.
func _draw_drive_bay() -> void:
	var face := side * BAY_FACE
	var edge := _local_x(_edge_world(-6.0))
	if (face - edge) * -side <= 4.0: return
	var span := absf(edge - face)
	draw_rect(Rect2(minf(edge, face), 66, span, 334), Color(0.028, 0.02, 0.05))
	var level := lerpf(0.12, 0.6, power)
	Neon.line(self, Vector2(face, 66), Vector2(face, 400), STRUCTURE, 1.5, level)
	for y in [78.0, 344.0]:
		Neon.line(self, Vector2(edge, y), Vector2(face, y), STRUCTURE, 1.2, level)
	var pitch := 7.0
	var crawl := fposmod(drive_phase * 1.6, pitch)
	for y in SCREW_Y:
		Neon.line(self, Vector2(edge, y), Vector2(face, y), STRUCTURE, 1.0, level * 0.6)
		var t := crawl
		while t < span:
			var tx := edge - side * t
			Neon.line(self, Vector2(tx - 2.0, y - 2.0), Vector2(tx + 2.0, y + 2.0), STRUCTURE, 0.8, level)
			t += pitch
		_draw_gear(Vector2(_local_x(_edge_world(4.0)), y), 8.0, drive_phase * 0.15 * side)
	var mouth := _local_x(_edge_world(2.0))
	for y in RAM_Y:
		var housing := Vector2(edge - side * 5.0, y)
		var brace := PackedVector2Array([housing + Vector2(-6, -10), housing + Vector2(6, -10), housing + Vector2(6, 10), housing + Vector2(-6, 10), housing + Vector2(-6, -10)])
		Neon.stroke(self, brace, STRUCTURE, 1.2, level)
		if (face - mouth) * -side > 0.0:
			Neon.line(self, Vector2(mouth, y), Vector2(face, y), STRUCTURE, 2.0, level + (0.25 if closing else 0.0))
		Neon.line(self, Vector2(face, y - 5), Vector2(face, y + 5), STRUCTURE, 2.0, level)
		var hose := PackedVector2Array([Vector2(edge, y + 10), Vector2(lerpf(edge, face, 0.35), y + 18), Vector2(lerpf(edge, face, 0.7), y + 18), Vector2(face, y + 7)])
		Neon.stroke(self, hose, STRUCTURE, 0.7, level * 0.4)


func _draw_gear(center: Vector2, radius: float, angle: float) -> void:
	var outline := PackedVector2Array()
	for i in 8:
		var start := angle + TAU * i / 8.0
		for offset in [0.0, 0.15, 0.45, 0.6]:
			var r := radius * (0.72 if offset == 0.0 or offset == 0.6 else 1.0)
			outline.append(center + Vector2.RIGHT.rotated(start + TAU / 8.0 * offset) * r)
	outline.append(outline[0])
	Neon.stroke(self, outline, STRUCTURE, 0.8, lerpf(0.12, 0.6, power))


## Casing vent slits glow while charging.
func _draw_vents() -> void:
	var charge := clampf(1.0 - fire_clock / FIRE_WARNING, 0.0, 1.0) if not charging.is_empty() else 0.0
	for i in VENT_Y.size():
		var hot := charging.has(i)
		var color := Color(1.0 + charge * 1.2, 0.2 + charge * 0.25, 0.4, 0.4 + charge * 0.6) if hot else Color(0.25, 0.13, 0.45)
		var x0 := side * 12.0
		var x1 := side * 3.0
		draw_rect(Rect2(minf(x0, x1), VENT_Y[i] - 5.0, absf(x1 - x0), 10), color)


## Inner-face guide lamps: dim at rest, filling bottom-up before a lunge; the whole row dies with the power.
func _draw_guide_lamps() -> void:
	var lamp_x := side * (4.0 if casing_breached else 18.0)
	var level := lerpf(0.12, 1.0, power)
	for i in 29:
		var y := 76.0 + i * 10.0
		var fill := (356.0 - y) / 280.0
		var lit := warning > 0.0 and fill <= warning
		var color := Color(2.0, 0.25, 0.5) if lit else Color(0.36, 0.18, 0.65)
		if lit and warning > 0.85 and int(age * 16.0) % 2 == 0: color = Color(2.2, 0.3, 0.25)
		draw_rect(Rect2(lamp_x - 1.5, y, 3, 5), Color(color.r * level, color.g * level, color.b * level))


func _draw_optic_arm() -> void:
	var root := Vector2(side * 18.0, optic.position.y)
	Neon.line(self, root, optic.position, STRUCTURE, 2.0, lerpf(0.12, 0.65, power))
	var bracket := PackedVector2Array([root + Vector2(-3, -4), root + Vector2(3, -4), root + Vector2(3, 4), root + Vector2(-3, 4), root + Vector2(-3, -4)])
	Neon.stroke(self, bracket, STRUCTURE, 1.0, lerpf(0.12, 0.6, power))
