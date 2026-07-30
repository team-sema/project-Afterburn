extends Enemy

## Drone (`enemy_drone.svg`): straight diagonal formation dive (no sine curve).

const FormationDiagonalMoveComponentScript := preload(
	"res://components/formation_diagonal_move_component.gd"
)


func setup_formation(
	origin: Vector2,
	offset: Vector2,
	shared_start_time: float,
	movement_settings: Dictionary = {},
) -> void:
	var diagonal := get_node_or_null("FormationDiagonalMoveComponent")
	assert(diagonal != null, "NormalEnemy requires FormationDiagonalMoveComponent.")
	assert(
		diagonal.get_script() == FormationDiagonalMoveComponentScript,
		"FormationDiagonalMoveComponent script mismatch.",
	)
	diagonal.call("setup_formation", origin, offset, shared_start_time, movement_settings)
