extends BarrageSequence
## Short spiral bursts from each turret muzzle, with rests between waves.
## Origins must be enemy-local offsets of the active turret muzzles.


func build(params: Dictionary) -> void:
	var offsets: Array = params.get("origin_offsets", [])
	if offsets.is_empty():
		push_warning("BossWallTurretPattern: missing origin_offsets; refusing to fire from ZERO.")
		return
	var start_angles: Array = params.get("start_angles", [])
	var wave_count := int(params.get("wave_count", 3))
	var shots_per_burst := int(params.get("shots_per_burst", 5))
	var speed := float(params.get("speed", 42.0))
	var shot_gap := float(params.get("shot_gap", 0.1))
	var muzzle_gap := float(params.get("muzzle_gap", 0.4))
	var wave_rest := float(params.get("wave_rest", 1.25))
	var step_degrees := float(params.get("step_degrees", 16.0))
	var shot := preload("res://resources/projectiles/round_straight_shot.tres")
	var angles: Array[float] = []
	for i in offsets.size():
		var base := float(params.get("base_angle", 0.0))
		if i < start_angles.size():
			base += float(start_angles[i])
		angles.append(base)
	var muzzle_count := offsets.size()
	for wave_index in maxi(1, wave_count):
		for muzzle_index in muzzle_count:
			var origin := offsets[muzzle_index] as Vector2
			if not origin.is_finite():
				continue
			for _shot_index in maxi(1, shots_per_burst):
				var volley := BarrageVolley.new()
				volley.shot = shot
				volley.layout = BarrageVolley.Layout.SINGLE
				volley.count = 1
				volley.speed = maxf(1.0, speed)
				volley.angle_degrees = angles[muzzle_index]
				volley.origin_offset = origin
				fire(volley)
				angles[muzzle_index] = angles[muzzle_index] + step_degrees
				wait(maxf(0.04, shot_gap))
			if muzzle_index < muzzle_count - 1:
				wait(maxf(0.05, muzzle_gap))
		if wave_index < wave_count:
			wait(maxf(0.2, wave_rest))
