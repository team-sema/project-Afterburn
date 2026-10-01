extends BarrageSequence
## RECYCLER Lab attacks: casing vents, press spit walls and the crush fan. Fixed emitters; nothing tracks the ship.


func build(params: Dictionary) -> void:
	var kind := String(params.get("kind", "crossfire"))
	var shot := BarrageShot.new()
	shot.appearance = preload("res://resources/projectiles/round.tres")
	shot.behavior = BulletBehavior.new()
	shot.lifetime = float(params.get("lifetime", 6.0))
	match kind:
		"crossfire":
			# Horizontal fan toward the opposite wall; lifetime ends it at that wall.
			var angle := float(params.get("angle", -90.0))
			for i in 3:
				var fan := BarrageVolley.new()
				fan.shot = shot
				fan.layout = BarrageVolley.Layout.FAN
				fan.count = 3
				fan.spread_degrees = 36.0
				fan.angle_degrees = angle
				fan.speed = 75.0
				fire(fan)
				if i < 2: wait(0.22)
		"gap_wall":
			# Rows across the whole press with a two-cell gap that drifts one cell per row; slope follows a V-shaped emitter edge.
			var left := float(params.get("left", -140.0))
			var cells := int(params.get("cells", 15))
			var gap := int(params.get("gap", 5))
			var drift := int(params.get("drift", 1))
			var y := float(params.get("y", 4.0))
			var slope := float(params.get("slope", 0.0))
			for row in 3:
				var bullets: Array[BarrageVolley] = []
				for cell in cells:
					if cell == gap or cell == gap + 1: continue
					var bullet := BarrageVolley.new()
					bullet.shot = shot
					var x := left + cell * 20.0
					bullet.origin_offset = Vector2(x, y - slope * absf(x))
					bullet.speed = 70.0
					bullets.append(bullet)
				fire_together(bullets)
				gap = clampi(gap + drift, 0, cells - 2)
				if gap == 0 or gap == cells - 2: drift = -drift
				if row < 2: wait(0.5)
		"crush_fan":
			var fan := BarrageVolley.new()
			fan.shot = shot
			fan.layout = BarrageVolley.Layout.FAN
			fan.count = 9
			fan.spread_degrees = 150.0
			fan.speed = 90.0
			fire(fan)
