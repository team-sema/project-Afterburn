extends BarrageSequence
## Mounted weapons use the articulated muzzle's transform for every volley.
func build(params: Dictionary) -> void:
	var mode := int(params.get("mode", 0))
	var variant := int(params.get("variant", 0))
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/round.tres")
	shot.behavior = BulletBehavior.new()
	shot.lifetime = 4.0
	if mode == 3:
		aim()
		var fighter_volley := BarrageVolley.new()
		fighter_volley.shot = shot
		fighter_volley.layout = BarrageVolley.Layout.FAN
		fighter_volley.count = 3
		fighter_volley.spread_degrees = 22
		fighter_volley.speed = 105
		fighter_volley.aim = BarrageVolley.Aim.LOCKED
		fire(fighter_volley)
		return
	var volleys := 5 if mode == 2 else 3
	for i in volleys:
		var volley := BarrageVolley.new()
		volley.shot = shot
		volley.relative_to_emitter = true
		volley.layout = BarrageVolley.Layout.FAN
		volley.count = [2, 1, 3][variant] if mode != 2 else [5, 3, 6][variant]
		volley.spread_degrees = [14.0, 0.0, 38.0][variant] if mode != 2 else [90.0, 24.0, 110.0][variant]
		volley.speed = [105.0, 135.0, 95.0][variant] if mode != 2 else 110.0
		fire(volley)
		if i < volleys - 1: wait(0.24 if variant != 2 else 0.32)
