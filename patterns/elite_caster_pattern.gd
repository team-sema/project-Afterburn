extends BarrageSequence
## Elite Caster spells. The actor plays one finite spell at a time (`spell` 0-2)
## and owns the rest between them. Without `spell` (Bullet Lab) the whole cycle
## repeats with its rests. `angle` is the locked reference direction (down = 0).

enum Spell { BREATHING_RINGS, PETAL_LATTICE, HALT_AND_AIM }

const ROUND := preload("res://resources/projectiles/round.tres")
const NEEDLE := preload("res://resources/projectiles/elite_needle.tres")
const PINK := Color(1.0, 0.22, 0.52)
const VIOLET := Color(0.7, 0.42, 1.0)
const RED := Color(1.0, 0.28, 0.3)
const WHITE := Color(0.95, 0.95, 1.0)
const LIFETIME := 8.0
const REST := 1.4

var _rate := 1.0


func build(params: Dictionary) -> void:
	_rate = clampf(float(params.get("rate", 1.0)), 0.01, 1.5)
	var angle := float(params.get("angle", 0.0))
	var spin := float(params.get("spin", 9.0))
	var extra := int(params.get("extra_shots", 0))
	if not params.has("spell"):
		breathing_rings(angle, spin)
		wait(REST)
		petal_lattice(angle)
		wait(REST)
		halt_and_aim(angle, extra)
		wait(REST)
		repeat()
		return
	match int(params["spell"]):
		Spell.BREATHING_RINGS: breathing_rings(angle, spin)
		Spell.PETAL_LATTICE: petal_lattice(angle)
		_: halt_and_aim(angle, extra)


## Rings brake near the caster and wait so all five accelerate together; each
## layer's lane is turned by `spin`, so the shared lane curves.
func breathing_rings(angle: float, spin: float) -> void:
	var rings := 5
	var gap := 0.45 / _rate
	for index in rings:
		var behavior := BulletBehavior.new()
		behavior.speed_to(25.0, 0.6).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)
		behavior.wait(0.5 + (rings - 1 - index) * gap)
		behavior.speed_to(95.0, 0.8).eased(Tween.TRANS_QUAD, Tween.EASE_IN)
		fire_fan(_shot(ROUND, PINK, behavior), 20, 320.0, 150.0, angle + 180.0 + index * spin)
		if index < rings - 1: wait(gap)


## Two rings bend 100 degrees in opposite directions and weave diamond cells.
func petal_lattice(angle: float) -> void:
	var left := _shot(ROUND, PINK, BulletBehavior.new().wait(0.3).turn_by(100.0, 1.4).eased(Tween.TRANS_SINE, Tween.EASE_IN_OUT))
	var right := _shot(ROUND, VIOLET, BulletBehavior.new().wait(0.3).turn_by(-100.0, 1.4).eased(Tween.TRANS_SINE, Tween.EASE_IN_OUT))
	for index in 4:
		fire_together([_ring(left, 12, 75.0, angle + index * 13.0), _ring(right, 12, 75.0, angle + index * 13.0)])
		if index < 3: wait(0.7 / _rate)


## Needles halt, turn red as the warning, snap toward the target and launch.
func halt_and_aim(angle: float, extra_shots: int) -> void:
	var behavior := BulletBehavior.new()
	behavior.speed_to(0.0, 0.7).eased(Tween.TRANS_QUAD, Tween.EASE_OUT)
	behavior.tint_to(RED, 0.0)
	behavior.wait(0.35)
	behavior.homing(1440.0, 0.25)
	behavior.speed_to(190.0, 0.5).eased(Tween.TRANS_QUAD, Tween.EASE_IN)
	var knife := _shot(NEEDLE, WHITE, behavior)
	var count := 16 + maxi(0, extra_shots)
	for index in 2:
		fire(_ring(knife, count, 140.0, angle + index * 180.0 / count))
		if index < 1: wait(1.0 / _rate)


func _ring(shot: BarrageShot, count: int, speed: float, angle: float) -> BarrageVolley:
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.layout = BarrageVolley.Layout.RING
	volley.count = count
	volley.speed = speed
	volley.angle_degrees = angle
	return volley


func _shot(appearance: BulletAppearance, tint: Color, behavior: BulletBehavior) -> BarrageShot:
	var shot := BarrageShot.new()
	var look := appearance.duplicate() as BulletAppearance
	look.tint = tint
	shot.appearance = look
	shot.behavior = behavior
	shot.lifetime = LIFETIME
	return shot
