extends Node2D

@onready var hitbox_component: HitboxComponent = $Anchor/HitboxComponent
@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var move_component: MoveComponent = $MoveComponent


func _ready() -> void:
	scale_component.tween_scale()
	hitbox_component.hit_hurtbox.connect(queue_free.unbind(1))


func launch(direction: Vector2, speed: float) -> void:
	move_component.velocity = direction.normalized() * speed
