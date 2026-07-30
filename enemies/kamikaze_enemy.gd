extends Enemy

## Awl kamikaze wingman: no shots. Formation V via KamikazeAimChargeComponent.

const KamikazeAimChargeComponentScript := preload(
	"res://components/kamikaze_aim_charge_component.gd"
)


func _enter_tree() -> void:
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		shoot.free()


func setup_formation(
	origin: Vector2,
	offset: Vector2,
	shared_start_time: float,
	movement_settings: Dictionary = {},
) -> void:
	var charge := get_node_or_null("KamikazeAimChargeComponent")
	assert(charge != null, "KamikazeEnemy requires KamikazeAimChargeComponent.")
	assert(
		charge.get_script() == KamikazeAimChargeComponentScript,
		"KamikazeAimChargeComponent script mismatch.",
	)
	charge.call("setup_formation", origin, offset, shared_start_time, movement_settings)
