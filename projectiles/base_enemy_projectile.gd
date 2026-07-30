extends Node2D

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var move_component: MoveComponent = $MoveComponent


func _ready() -> void:
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(queue_free.unbind(1))


func launch(direction: Vector2, speed: float) -> void:
	move_component.velocity = direction.normalized() * speed
	rotation = direction.angle() + PI * 0.5
