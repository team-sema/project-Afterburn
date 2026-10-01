extends CanvasLayer
## Lab stand-in for the RECYCLER phase route, drawn above the starfield: a fortress grows on approach,
## its hull plating scrolls in around the hull gate, then a defended corridor leads into the bay.
## Progress comes from the encounter sequence; the scroll shares the boss's speed scale so the bay halts it.
## Placeholder shapes only — the main-game route art replaces them.
const Playfield = preload("res://menus/playfield_layout.gd")
const AMBER := Color(1.0, 0.62, 0.2)
const SIGNAL := Color(1.0, 0.16, 0.2)
## Route beats as fractions of the phase pattern.
const FORTRESS_FROM := 0.06
const HULL_FROM := 0.35
const HULL_COVERED := 0.55
const INTERIOR_FROM := 0.58
const INTERIOR_FULL := 0.68
const SCROLL_SPEED := 20.0

## Target route position, 0 = phase start, 1 = bay reached.
var progress := 0.0
## Eased position actually drawn.
var shown := 0.0
## 1 = cruise, 0 = halted at the bay (mirrors the starfield).
var speed_scale := 1.0
var scroll := 0.0
var age := 0.0
var canvas: Node2D


func _ready() -> void:
	layer = -90
	follow_viewport_enabled = false
	canvas = Node2D.new()
	canvas.draw.connect(_draw_route)
	add_child(canvas)


static func beat_title(route_progress: float) -> String:
	if route_progress >= 1.0: return "INTERIOR / BAY AHEAD"
	if route_progress >= INTERIOR_FROM: return "INTERIOR / DEFENSES"
	if route_progress >= HULL_FROM: return "APPROACH / FORTRESS AHEAD"
	return "APPROACH / OPEN SPACE"


func _process(delta: float) -> void:
	age += delta
	shown = move_toward(shown, progress, delta * 0.06)
	scroll = fposmod(scroll + SCROLL_SPEED * speed_scale * delta, 48.0)
	canvas.queue_redraw()


func _draw_route() -> void:
	var width := float(Playfield.SIZE.x)
	var height := float(Playfield.SIZE.y)
	# Approach: a distant silhouette at the top grows until it spans the field.
	var sighting := smoothstep(FORTRESS_FROM, HULL_FROM, shown)
	var cover := smoothstep(HULL_FROM, HULL_COVERED, shown)
	if sighting > 0.0 and cover < 1.0:
		var half := lerpf(6.0, width * 0.5, sighting)
		var depth := lerpf(4.0, 42.0, sighting)
		var silhouette := PackedVector2Array([
			Vector2(width * 0.5 - half, -2.0), Vector2(width * 0.5 + half, -2.0),
			Vector2(width * 0.5 + half * 0.82, depth), Vector2(width * 0.5 - half * 0.82, depth),
		])
		canvas.draw_colored_polygon(silhouette, Color(0.05, 0.045, 0.07, sighting * (1.0 - cover)))
		canvas.draw_polyline(silhouette + PackedVector2Array([silhouette[0]]), Color(AMBER, 0.45 * sighting * (1.0 - cover)), 1.0, true)
		for i in 5:
			var t := (i + 0.5) / 5.0
			var lit := int(age * 2.0 + i) % 3 == 0
			var lamp := Vector2(lerpf(width * 0.5 - half * 0.7, width * 0.5 + half * 0.7, t), depth * 0.55)
			canvas.draw_circle(lamp, 1.2 + sighting, Color(AMBER, (0.8 if lit else 0.3) * sighting * (1.0 - cover)))
	# Hull: plating scrolls down from the top until the whole field is fortress surface.
	if cover > 0.0:
		var edge := lerpf(-30.0, height + 40.0, cover)
		canvas.draw_rect(Rect2(0, -20, width, edge + 20.0), Color(0.05, 0.045, 0.065))
		var seam := Color(0.16, 0.14, 0.2)
		var y := fmod(scroll, 48.0) - 48.0
		while y < edge:
			if y > -20.0:
				canvas.draw_line(Vector2(0, y), Vector2(width, y), seam, 1.5)
			y += 48.0
		for x in [0.0, 96.0, 204.0, 300.0]:
			canvas.draw_line(Vector2(x, -20), Vector2(x, edge), seam, 1.5)
		canvas.draw_line(Vector2(0, edge), Vector2(width, edge), Color(AMBER, 0.55), 2.0)
	# Interior: corridor walls with running lamps close in on both sides.
	var inside := smoothstep(INTERIOR_FROM, INTERIOR_FULL, shown)
	if inside > 0.0:
		var wall := 26.0 * inside
		var wall_color := Color(0.09, 0.075, 0.1)
		canvas.draw_rect(Rect2(0, -20, wall, height + 40.0), wall_color)
		canvas.draw_rect(Rect2(width - wall, -20, wall, height + 40.0), wall_color)
		var y := fmod(scroll, 48.0) - 48.0
		while y < height + 20.0:
			for x in [wall - 6.0, width - wall + 3.0]:
				canvas.draw_rect(Rect2(x, y, 3, 8), Color(AMBER, 0.7 * inside))
			canvas.draw_line(Vector2(wall, y + 24.0), Vector2(width - wall, y + 24.0), Color(0.12, 0.1, 0.14, inside), 1.0)
			y += 48.0
		canvas.draw_line(Vector2(wall, -20), Vector2(wall, height + 20), Color(AMBER, 0.35 * inside), 1.5)
		canvas.draw_line(Vector2(width - wall, -20), Vector2(width - wall, height + 20), Color(AMBER, 0.35 * inside), 1.5)
