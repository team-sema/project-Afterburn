class_name BarrageStep
extends Resource

## Saved enum numbers are stable; new actions append at the end.
enum Action { FIRE, WAIT, ROTATE, ROTATE_TO, AIM }
@export var action: Action = Action.FIRE
@export var volley: BarrageVolley
@export var volleys: Array[BarrageVolley] = []
@export var value := 0.0

func get_volleys() -> Array[BarrageVolley]:
	return volleys if not volleys.is_empty() else [volley]
