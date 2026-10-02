extends BarrageSequence
## Elite Bomb minefield: three orb rings brake into floating layers, swell white
## as the warning, then twist outward. The actor owns the body warning and rest;
## without params (Bullet Lab) the field repeats with a rest. `angle`: down = 0.

const ORB := preload("res://resources/projectiles/orb.tres")
const ORB_TINT := Color(1.0, 0.3, 0.4)
const WARNING_TINT := Color(0.95, 0.95, 1.0)
const LAYERS := [[70.0, 0.0], [105.0, 15.0], [140.0, 7.5]]


func build(params: Dictionary) -> void:
	var angle := float(params.get("angle", 0.0))
	var gap := 1.2 / clampf(float(params.get("rate", 1.0)), 0.01, 1.5)
	for burst in 2:
		var layers: Array[BarrageVolley] = []
		var shot := _orb(1.0 if burst == 0 else -1.0)
		for layer in LAYERS:
			var volley := BarrageVolley.new()
			volley.shot = shot
			volley.layout = BarrageVolley.Layout.RING
			volley.count = 8
			volley.speed = layer[0]
			volley.angle_degrees = angle + layer[1] + burst * 22.5
			layers.append(volley)
		fire_together(layers)
		if burst == 0: wait(gap)
	if params.is_empty():
		wait(3.0)
		repeat()


func _orb(twist: float) -> BarrageShot:
	var behavior := BulletBehavior.new()
	behavior.speed_to(0.0, 1.2).eased(Tween.TRANS_QUAD, Tween.EASE_IN)
	behavior.wait(1.0)
	behavior.parallel([BulletAction.tint_to(WARNING_TINT, 0.35), BulletAction.visual_scale_to(1.35, 0.35)])
	behavior.parallel([BulletAction.make(BulletAction.Type.SPEED, 120.0, 1.0), BulletAction.turn_by(30.0 * twist, 1.0)])
	var shot := BarrageShot.new()
	var look := ORB.duplicate() as BulletAppearance
	look.tint = ORB_TINT
	look.core_size = Vector2(12, 12)
	look.collision_radius = 4.5
	look.collision_height = 9.0
	shot.appearance = look
	shot.behavior = behavior
	shot.lifetime = 8.0
	return shot
