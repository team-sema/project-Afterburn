class_name MovementSpaceConfig
extends Resource

## MovementSpace is deliberately larger than the visible camera rectangle.
@export_range(0.0, 2.0, 0.01) var movement_margin_x_ratio := 0.20
@export_range(0.0, 2.0, 0.01) var movement_margin_top_ratio := 0.20
@export_range(0.0, 2.0, 0.01) var movement_margin_bottom_ratio := 0.25

## DespawnSpace must contain MovementSpace so paths can turn around off-camera.
@export_range(0.0, 3.0, 0.01) var despawn_margin_x_ratio := 0.55
@export_range(0.0, 3.0, 0.01) var despawn_margin_top_ratio := 0.45
@export_range(0.0, 3.0, 0.01) var despawn_margin_bottom_ratio := 0.50

## Only explicit combat-positioning steps use this inset rectangle.
@export_range(0.0, 0.45, 0.01) var combat_inset_x_ratio := 0.05
@export_range(0.0, 0.45, 0.01) var combat_inset_top_ratio := 0.04
@export_range(0.0, 0.45, 0.01) var combat_inset_bottom_ratio := 0.08


func get_movement_area(visible_rect: Rect2) -> Rect2:
	return visible_rect.grow_individual(
		visible_rect.size.x * movement_margin_x_ratio,
		visible_rect.size.y * movement_margin_top_ratio,
		visible_rect.size.x * movement_margin_x_ratio,
		visible_rect.size.y * movement_margin_bottom_ratio,
	)


func get_despawn_area(visible_rect: Rect2) -> Rect2:
	return visible_rect.grow_individual(
		visible_rect.size.x * despawn_margin_x_ratio,
		visible_rect.size.y * despawn_margin_top_ratio,
		visible_rect.size.x * despawn_margin_x_ratio,
		visible_rect.size.y * despawn_margin_bottom_ratio,
	)


func get_combat_area(visible_rect: Rect2) -> Rect2:
	return visible_rect.grow_individual(
		-visible_rect.size.x * combat_inset_x_ratio,
		-visible_rect.size.y * combat_inset_top_ratio,
		-visible_rect.size.x * combat_inset_x_ratio,
		-visible_rect.size.y * combat_inset_bottom_ratio,
	)


func validate() -> bool:
	return (
		despawn_margin_x_ratio >= movement_margin_x_ratio
		and despawn_margin_top_ratio >= movement_margin_top_ratio
		and despawn_margin_bottom_ratio >= movement_margin_bottom_ratio
	)
