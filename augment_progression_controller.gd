class_name AugmentProgressionController
extends Node

const OPEN_AUGMENT_OFFER_ACTION := &"open_augment_offer"

signal experience_changed(current_experience: int, experience_required: int, level: int)
signal enemy_augment_progress_changed(elapsed: float, interval: float, current_threat_level: int)
signal threat_level_changed(current_level: int)

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


func _ready() -> void:
	assert(offer_controller != null, "AugmentProgressionController requires an AugmentOfferController.")
	experience_required = base_experience_required
	offer_controller.offer_completed.connect(_on_offer_completed)
	publish_state()


func publish_state() -> void:
	experience_changed.emit(current_experience, experience_required, level)
	enemy_augment_progress_changed.emit(enemy_augment_elapsed, enemy_augment_interval, get_threat_level())
	threat_level_changed.emit(get_threat_level())


func get_threat_level() -> int:
	return enemy_augment_tier + 1


func _process(delta: float) -> void:
	var previous_threat_level := get_threat_level()
	enemy_augment_elapsed += delta
	while enemy_augment_elapsed >= enemy_augment_interval:
		enemy_augment_elapsed -= enemy_augment_interval
		enemy_augment_tier += 1
		pending_offers.append(AugmentOfferController.OfferType.ENEMY)
	var current_threat_level := get_threat_level()
	if current_threat_level != previous_threat_level:
		threat_level_changed.emit(current_threat_level)
	enemy_augment_progress_changed.emit(enemy_augment_elapsed, enemy_augment_interval, current_threat_level)
	if Input.is_action_just_pressed(OPEN_AUGMENT_OFFER_ACTION):
		_try_level_up()
	_try_request_offer()


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	current_experience += amount
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


func _on_offer_completed(_offer_type: AugmentOfferController.OfferType) -> void:
	_try_request_offer.call_deferred()
