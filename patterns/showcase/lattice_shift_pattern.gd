extends BarrageSequence
## Showcase: lattice shift (diamond cage). The field fills with a diamond
## lattice whose lines are walls of densely packed bullets: red bullets make the
## "\" lines, blue bullets the "/" lines, 9 px apart, so nothing slips between
## them. The player lives inside a cell.
##
## Red lines only ever move left and blue lines only right. Pulling the two
## families apart that way moves the whole lattice down: the cage descends.
##   1. Descent (solid): each family moves 20 px, the cage sinks a quarter cell.
##      Follow your cell down.
##   2. Split (ghost): every bullet fades and each family moves 40 px more, the
##      cage drops half a cell at once, so the new crossings land on the old
##      cell centres. Pass through the ghost walls into a new cell (half a
##      column sideways, or half a cell up) before it turns solid again.
## Over four cycles the solid descents sweep every height, so standing still
## is always hit.
##
## Bullets never move vertically, so every cycle the lattice is fed with the
## bullets that will enter the field from the sides (red from the right, blue
## from the left); the cage keeps its shape while its bullets stream across.
## The first cage appears as ghosts and slides into place like any other split.
##
## Each bullet repeats one cycle forever (12 actions), and bullets of the same
## colour and spawn tick share one shot. Bullets are fired during the ghost
## hold, a few physics ticks apart to spread the spawn cost; a group fired g
## ticks late holds g ticks less and its cycle ends with those g ticks, so
## every bullet keeps the same timeline.

const Shots := preload("res://labs/bullet/showcase_shots.gd")
const RED := Color(1.0, 0.2, 0.25)
const BLUE := Color(0.25, 0.4, 1.0)

## Cell: 80 px wide (S), 96 px tall (2h). Line slope k = h / (S/2).
const CELL_WIDTH := 80.0
const HALF_HEIGHT := 48.0
const SLOPE := HALF_HEIGHT / (CELL_WIDTH * 0.5)
## Bullets per cell edge; spacing along a line = 62.5 / 7 = 8.9 px, below the
## 12 px a 3 px player core needs between two 3 px bullets.
const EDGE_BULLETS := 7

## Both families moving `d` px apart (red left, blue right) lower every
## crossing by k * d.
const DESCENT_MOVE := 20.0 # Cage sinks 24 px (a quarter cell).
const SPLIT_MOVE := CELL_WIDTH * 0.5 # Cage drops 48 px (half a cell).
const CYCLE_MOVE := DESCENT_MOVE + SPLIT_MOVE

## Durations are multiples of 1/120 s.
const TICK := 1.0 / 60.0
const GHOST_HOLD_SECONDS := 0.3
const SPLIT_SECONDS := 0.6
const SOLIDIFY_SECONDS := 0.25
const DESCENT_SECONDS := 0.9
const GHOST_FADE_SECONDS := 0.125
const GHOST_OPACITY := 0.28
const CYCLE_SECONDS := GHOST_HOLD_SECONDS + SPLIT_SECONDS + SOLIDIFY_SECONDS + DESCENT_SECONDS + GHOST_FADE_SECONDS
## Spawn groups must fit inside the ghost hold.
const MAX_GROUPS := 18

## Cycles fed per round; the cage then drains (its bullets cross the field
## within 8 cycles) before the next round appears.
const CYCLES := 24
const DRAIN_CYCLES := 9
const LIFE_CYCLES := 10
## Bullets per family per physics tick (two families per FIRE step).
const GROUP_SIZE := 16
const EDGE_PAD := 4.0

## Field rectangle relative to the emitter. Defaults fit the Bullet Lab
## (416 x 288 field, emitter at x 208, y 28).
var _field := Rect2(-208, -28, 416, 288)
var _shots := {}


func build(params: Dictionary) -> void:
	_field = params.get("field", _field)
	var inside := _field.grow(EDGE_PAD)
	# Each family at the ghost hold of the four cycle phases (the set repeats
	# every four cycles: 4 * 60 px is three columns).
	var first := {}
	var fed: Array[Dictionary] = [{}, {}, {}, {}]
	for side in [-1.0, 1.0]:
		var base := _base_points(side)
		var split := Vector2(side * SPLIT_MOVE, 0)
		var cycle := Vector2(side * CYCLE_MOVE, 0)
		first[side] = base.filter(func(point: Vector2) -> bool:
			return inside.has_point(point) or inside.has_point(point + split) or inside.has_point(point + cycle))
		for phase in 4:
			var points := []
			for point: Vector2 in base:
				var at := point + cycle * phase
				if not inside.has_point(at) and (inside.has_point(at + split) or inside.has_point(at + cycle)):
					points.append(at)
			fed[phase][side] = points
	for index in CYCLES:
		var groups := _fire_groups(first if index == 0 else fed[index % 4])
		wait(CYCLE_SECONDS - groups * TICK)
	wait(DRAIN_CYCLES * CYCLE_SECONDS)
	repeat()


## Lattice points of one family at the first ghost hold. `side` is its travel
## direction: -1 = red "\" lines (x - y / k = S * i), +1 = blue "/" lines
## (x + y / k = S * i). Covers the field plus everything that can still cross
## into it within a bullet's life.
func _base_points(side: float) -> Array:
	var points := []
	var spacing := HALF_HEIGHT / EDGE_BULLETS
	var top := _field.position.y - HALF_HEIGHT
	var bottom := _field.end.y + HALF_HEIGHT
	var reach := LIFE_CYCLES * CYCLE_MOVE + CELL_WIDTH + maxf(absf(top), absf(bottom)) / SLOPE
	var first_column := floori((_field.position.x - reach) / CELL_WIDTH)
	var last_column := ceili((_field.end.x + reach) / CELL_WIDTH)
	for row in range(floori(top / spacing), ceili(bottom / spacing) + 1):
		var y := row * spacing
		for column in range(first_column, last_column + 1):
			points.append(Vector2(column * CELL_WIDTH - side * y / SLOPE, y))
	return points


## Fires both families GROUP_SIZE bullets per physics tick. Returns the number
## of ticks used.
func _fire_groups(lattice: Dictionary) -> int:
	var largest := maxi((lattice[-1.0] as Array).size(), (lattice[1.0] as Array).size())
	var groups := clampi(ceili(largest / float(GROUP_SIZE)), 1, MAX_GROUPS)
	var per_group := ceili(largest / float(groups))
	for group in groups:
		var volleys: Array[BarrageVolley] = []
		for side in [-1.0, 1.0]:
			var points: Array = lattice[side]
			var shot := _shot(side, group)
			for index in range(group * per_group, mini((group + 1) * per_group, points.size())):
				var volley := BarrageVolley.new()
				volley.shot = shot
				volley.speed = 0.0
				volley.origin_offset = points[index]
				volleys.append(volley)
		if not volleys.is_empty():
			fire_together(volleys)
		wait(TICK)
	return groups


## Half a lateral wave from its trough: a smooth 0 -> `distance` sideways move.
## Bullets fire straight down at speed 0, so the lateral axis is screen-right.
static func _sideways(distance: float, seconds: float) -> BulletAction:
	var action := BulletAction.make(BulletAction.Type.LATERAL_WAVE, distance * 0.5, seconds)
	action.period = seconds * 2.0
	action.phase = -PI * 0.5
	return action


## One cycle, starting in the ghost hold: hold -> split -> solidify -> descent
## (solid) -> ghost fade -> the `group` ticks this bullet was fired late.
func _shot(side: float, group: int) -> BarrageShot:
	var key := Vector2(side, group)
	if _shots.has(key):
		return _shots[key]
	var late := group * TICK
	var behavior := BulletBehavior.new()
	# Both are no-ops after the first cycle; they make a new bullet a ghost.
	behavior.intangible()
	behavior.opacity_to(GHOST_OPACITY, 0.0)
	behavior.wait(GHOST_HOLD_SECONDS - late)
	behavior.then(_sideways(side * SPLIT_MOVE, SPLIT_SECONDS))
	behavior.opacity_to(1.0, SOLIDIFY_SECONDS)
	behavior.tangible()
	behavior.then(_sideways(side * DESCENT_MOVE, DESCENT_SECONDS))
	behavior.intangible()
	behavior.opacity_to(GHOST_OPACITY, GHOST_FADE_SECONDS)
	behavior.wait(late)
	behavior.repeat()
	_shots[key] = Shots.bullet(Shots.ROUND, RED if side < 0.0 else BLUE, behavior, LIFE_CYCLES * CYCLE_SECONDS)
	return _shots[key]
