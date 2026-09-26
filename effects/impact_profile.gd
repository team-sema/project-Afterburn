class_name ImpactProfile
extends Resource

## Per-weapon hit look drawn by ImpactVfx: a contact flare, a spark spray and
## an optional area ring. Colors follow the weapon's projectile colors.

@export var glow_color := Color(0.1, 0.78, 1.0, 0.55)
@export var core_color := Color(0.9, 0.99, 1.0, 1.0)
## 0 skips the flare (e.g. when the weapon already spawns its own explosion).
@export_range(0.0, 16.0, 0.1) var flare_radius := 4.5
@export_range(0.01, 1.0, 0.01) var flare_lifetime := 0.12
@export_range(0, 16, 1) var spark_count := 4
@export_range(1.0, 600.0, 1.0) var spark_speed_min := 140.0
@export_range(1.0, 600.0, 1.0) var spark_speed_max := 260.0
## Half-angle of the spray cone around the emit direction.
@export_range(0.0, 180.0, 1.0) var spark_spread_degrees := 70.0
@export_range(0.0, 30.0, 0.1) var spark_drag := 4.0
@export_range(0.5, 20.0, 0.1) var spark_length := 7.0
@export_range(0.01, 1.0, 0.01) var spark_lifetime := 0.3
@export_range(0.01, 1.0, 0.01) var ring_lifetime := 0.25
@export_range(0.5, 6.0, 0.1) var ring_width := 1.5
