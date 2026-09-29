extends Node2D
## Faint drifting dust above the hull: forward motion stays readable even
## when the carrier fills the screen and hides the starfield.
const COUNT := 34
const SPEED := 60.0
var boss: Node2D
var clock := 0.0
var fade := 1.0

func _physics_process(delta: float) -> void:
	clock += delta
	if is_instance_valid(boss) and boss.defeated:
		fade = move_toward(fade, 0.0, delta * 2.0)
	queue_redraw()

func _draw() -> void:
	if fade <= 0: return
	for i in COUNT:
		var seed_x := float(hash(i * 31) % 240)
		var lane_speed := SPEED * (0.7 + float(hash(i * 17) % 60) / 100.0)
		var y := fposmod(float(hash(i * 13) % 360) + clock * lane_speed, 380.0) - 10.0
		var alpha := (0.08 + float(hash(i * 5) % 10) / 100.0) * fade
		draw_line(Vector2(seed_x, y), Vector2(seed_x, y + 5.0 + lane_speed * 0.04), Color(0.7, 0.75, 1.0, alpha), 1.0)
