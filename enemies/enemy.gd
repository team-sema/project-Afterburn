class_name Enemy
extends Node2D

var augment_registry: EnemyAugmentRegistry

@onready var stats_component: StatsComponent = $StatsComponent
@onready var move_component: MoveComponent = $MoveComponent
@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var shake_component: ShakeComponent = $ShakeComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var hurt_component: HurtComponent = $HurtComponent
@onready var score_component: ScoreComponent = $ScoreComponent
@onready var hit_sound_player: VariablePitchAudioStreamPlayer = $HitSoundPlayer

func _ready() -> void:
	stats_component.no_health.connect(func():
		score_component.adjust_score()
	)
	
	hurtbox_component.hurt.connect(func(hitbox: HitboxComponent):
		scale_component.tween_scale()
		flash_component.flash()
		shake_component.tween_shake()
		hit_sound_player.play_with_variance()
	)
	stats_component.no_health.connect(queue_free)
	hitbox_component.hit_hurtbox.connect(queue_free.unbind(1))
