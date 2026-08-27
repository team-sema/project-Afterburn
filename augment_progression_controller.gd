class_name AugmentProgressionController
extends Node

const OPEN_AUGMENT_OFFER_ACTION := &"open_augment_offer"

signal experience_changed(current_experience: int, experience_required: int, level: int)
signal enemy_augment_progress_changed(elapsed: float, interval: float, current_threat_level: int)
signal threat_level_changed(current_level: int)
signal elite_milestone_requested(threat_level: int)
signal elite_gate_changed(is_active: bool, threat_level: int)

@export var offer_controller: AugmentOfferController
@export_range(1, 100000, 1) var base_experience_required := 5
@export_range(0, 100000, 1) var experience_requirement_growth := 3
@export_range(1.0, 3600.0, 1.0) var enemy_augment_interval := 60.0

var level := 1
var current_experience := 0
var experience_required := 0
var enemy_augment_elapsed := 0.0
var enemy_augment_tier := 0
var pending_offers: Array[AugmentOfferController.OfferType] = []
var elite_gate_active := false
var active_elite_threat := 0
var _awaiting_elite_enemy_offer := false
## Facility XP_GAIN_MULT product. Applied in add_experience.
var experience_gain_multiplier := 1.0


func _ready() -> void:
	assert(offer_controller != null, "AugmentProgressionController requires an AugmentOfferController.")
	experience_required = base_experience_required
	offer_controller.offer_completed.connect(_on_offer_completed)
	publish_state()


func publish_state() -> void:
	experience_changed.emit(current_experience, experience_required, level)
	enemy_augment_progress_changed.emit(enemy_augment_elapsed, enemy_augment_interval, get_threat_level())
	threat_level_changed.emit(get_threat_level())
	elite_gate_changed.emit(elite_gate_active, active_elite_threat)


func get_threat_level() -> int:
	return enemy_augment_tier + 1


func _process(delta: float) -> void:
	if not elite_gate_active:
		enemy_augment_elapsed += delta
	if not elite_gate_active and enemy_augment_elapsed >= enemy_augment_interval:
		enemy_augment_elapsed = 0.0
		elite_gate_active = true
		active_elite_threat = get_threat_level() + 1
		elite_gate_changed.emit(true, active_elite_threat)
		elite_milestone_requested.emit(active_elite_threat)
	var current_threat_level := get_threat_level()
	enemy_augment_progress_changed.emit(enemy_augment_elapsed, enemy_augment_interval, current_threat_level)
	if Input.is_action_just_pressed(OPEN_AUGMENT_OFFER_ACTION):
		_try_level_up()
	_try_request_offer()


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	var gained := maxi(1, roundi(amount * maxf(0.01, experience_gain_multiplier)))
	current_experience += gained
	experience_changed.emit(current_experience, experience_required, level)


func _try_level_up() -> void:
	if current_experience < experience_required:
		return
	if not offer_controller.request_offer(AugmentOfferController.OfferType.PLAYER):
		return

	current_experience -= experience_required
	level += 1
	experience_required = base_experience_required + (level - 1) * experience_requirement_growth
	experience_changed.emit(current_experience, experience_required, level)


func _try_request_offer() -> void:
	if pending_offers.is_empty():
		return
	if offer_controller.request_offer(pending_offers.front()):
		pending_offers.pop_front()


func complete_elite_milestone(threat_level: int) -> bool:
	if not elite_gate_active or _awaiting_elite_enemy_offer:
		return false
	if threat_level != active_elite_threat:
		return false
	_awaiting_elite_enemy_offer = true
	enemy_augment_tier += 1
	assert(get_threat_level() == threat_level, "Elite defeat must advance exactly one Threat level.")
	threat_level_changed.emit(get_threat_level())
	enemy_augment_progress_changed.emit(
		enemy_augment_elapsed,
		enemy_augment_interval,
		get_threat_level(),
	)
	pending_offers.append(AugmentOfferController.OfferType.ENEMY)
	_try_request_offer()
	return true


func _on_offer_completed(offer_type: AugmentOfferController.OfferType) -> void:
	if offer_type == AugmentOfferController.OfferType.ENEMY and _awaiting_elite_enemy_offer:
		_awaiting_elite_enemy_offer = false
		elite_gate_active = false
		active_elite_threat = 0
		elite_gate_changed.emit(false, get_threat_level())
	_try_request_offer.call_deferred()
