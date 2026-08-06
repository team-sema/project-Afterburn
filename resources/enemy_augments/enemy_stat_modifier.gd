class_name EnemyStatModifier
extends Resource

enum Stat {
	HEALTH,
	MOVE_SPEED,
	ACTION_RATE,
	ARMING_RATE,
}

@export var stat: Stat = Stat.HEALTH
@export_range(0.01, 100.0, 0.05) var multiplier := 1.0
