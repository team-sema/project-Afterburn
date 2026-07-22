class_name PlayerStatModifier
extends Resource

enum Stat {
	MOVE_SPEED,
	FIRE_RATE,
	WEAPON_DAMAGE,
}

@export var stat: Stat = Stat.MOVE_SPEED
@export_range(0.01, 100.0, 0.05) var multiplier := 1.0
