extends BarrageSequence
## Mounted weapons use the articulated muzzle's transform for every volley.
## Shot shape tells threat: round = pressure, rice = aimed, orb = heavy shell.
const ROUND = preload("res://resources/projectiles/round.tres")
const RICE = preload("res://resources/projectiles/rice.tres")
const ORB = preload("res://resources/projectiles/orb.tres")

func build(params: Dictionary) -> void:
	var mode := int(params.get("mode", 0))
	var variant := int(params.get("variant", 0))
	if mode == 3 or mode == 7:
		# Hangar fighters spread a short fan; transit raiders snipe once.
		aim()
		var craft_volley := BarrageVolley.new()
		craft_volley.shot = _shot(ROUND if mode == 3 else RICE)
		craft_volley.layout = BarrageVolley.Layout.FAN
		craft_volley.count = 3 if mode == 3 else 1
		craft_volley.spread_degrees = 22
		craft_volley.speed = 105 if mode == 3 else 140
		craft_volley.aim = BarrageVolley.Aim.LOCKED
		fire(craft_volley)
		return
	if mode == 2 and variant == 4:
		# Overdrive ring: three rotating rings from the opened bridge core.
		for i in 3:
			var ring := BarrageVolley.new()
			ring.shot = _shot(ROUND)
			ring.relative_to_emitter = true
			ring.layout = BarrageVolley.Layout.RING
			ring.count = 12
			ring.speed = 80
			ring.angle_degrees = i * 15.0
			fire(ring)
			if i < 2: wait(0.4)
		return
	var volleys := 5 if mode == 2 else 3
	for i in volleys:
		var volley := BarrageVolley.new()
		volley.shot = _shot(_appearance(mode, variant))
		volley.relative_to_emitter = true
		volley.layout = BarrageVolley.Layout.FAN
		volley.count = [2, 1, 3][variant] if mode != 2 else [5, 3, 6][variant]
		volley.spread_degrees = [14.0, 0.0, 38.0][variant] if mode != 2 else [90.0, 24.0, 110.0][variant]
		volley.speed = [105.0, 135.0, 95.0][variant] if mode != 2 else [90.0, 125.0, 110.0][variant]
		fire(volley)
		if i < volleys - 1: wait(0.24 if variant != 2 else 0.32)

func _appearance(mode: int, variant: int) -> BulletAppearance:
	if variant == 1: return RICE
	if mode == 2 and variant == 0: return ORB
	return ROUND

func _shot(appearance: BulletAppearance) -> BarrageShot:
	var shot := BarrageShot.new()
	shot.appearance = appearance
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 4.5
	return shot
