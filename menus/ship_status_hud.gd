class_name ShipStatusHud
extends VBoxContainer

## 전투 중 선체·실드 게이지. 함선의 상태를 읽어 표시만 하고 값을 바꾸지 않는다.
## STATUS 패널의 모듈 슬롯 표시와는 다른 정보다 (여기는 현재 자원량).

@export var ship: Node2D

@onready var hull_label: Label = %HullLabel
@onready var hull_bar: ProgressBar = %HullBar
@onready var shield_label: Label = %ShieldLabel
@onready var shield_bar: ProgressBar = %ShieldBar
@onready var shield_charge_bar: ProgressBar = %ShieldChargeBar

var _stats: StatsComponent
var _shield: ShieldComponent
var _facility_applier: ShipFacilityApplier


func _ready() -> void:
	# 함선은 게임플레이 서브씬에 있어 한 프레임 뒤에 붙는다.
	call_deferred("_bind_ship")


func _bind_ship() -> void:
	if not is_instance_valid(ship):
		_show_offline()
		return
	_stats = ship.get_node_or_null("StatsComponent") as StatsComponent
	_shield = ship.get_node_or_null("ShieldComponent") as ShieldComponent
	_facility_applier = ship.get_node_or_null("ShipFacilityApplier") as ShipFacilityApplier
	if _stats != null and not _stats.health_changed.is_connected(_refresh_hull):
		_stats.health_changed.connect(_refresh_hull)
	if _shield != null and not _shield.shield_changed.is_connected(_on_shield_changed):
		_shield.shield_changed.connect(_on_shield_changed)
	if _shield != null and not _shield.charge_changed.is_connected(_on_charge_changed):
		_shield.charge_changed.connect(_on_charge_changed)
	if _facility_applier != null and not _facility_applier.max_hull_changed.is_connected(_on_max_hull_changed):
		_facility_applier.max_hull_changed.connect(_on_max_hull_changed)
	ship.tree_exited.connect(_show_offline)
	refresh()


func refresh() -> void:
	_refresh_hull()
	_refresh_shield()
	_refresh_charge()


func _refresh_hull() -> void:
	if _stats == null:
		return
	var max_hull := _get_max_hull()
	hull_bar.max_value = maxi(1, max_hull)
	hull_bar.value = clampi(_stats.health, 0, max_hull)
	hull_label.text = "HULL   %d / %d" % [maxi(0, _stats.health), max_hull]


func _refresh_shield() -> void:
	var current := _shield.get_current_shield() if _shield != null else 0
	var maximum := _shield.get_max_shield() if _shield != null else 0
	shield_bar.max_value = maxi(1, maximum)
	shield_bar.value = current
	shield_label.text = "SHIELD %d / %d" % [current, maximum]
	_refresh_charge()


func _refresh_charge() -> void:
	if shield_charge_bar == null:
		return
	if _shield == null:
		shield_charge_bar.visible = false
		shield_charge_bar.value = 0.0
		return
	var progress := _shield.get_charge_progress()
	var show_charge := _shield.get_max_shield() > 0 and _shield.get_current_shield() < _shield.get_max_shield()
	shield_charge_bar.visible = show_charge
	shield_charge_bar.max_value = 1.0
	shield_charge_bar.value = progress if show_charge else 0.0


func _get_max_hull() -> int:
	if _facility_applier != null:
		return _facility_applier.get_max_hull()
	return maxi(1, _stats.health) if _stats != null else 1


func _on_shield_changed(_current_shield: int, _max_shield: int) -> void:
	_refresh_shield()


func _on_charge_changed(_progress: float) -> void:
	_refresh_charge()


func _on_max_hull_changed(_max_hull: int) -> void:
	_refresh_hull()


func _show_offline() -> void:
	_stats = null
	_shield = null
	_facility_applier = null
	hull_bar.value = 0
	shield_bar.value = 0
	if shield_charge_bar != null:
		shield_charge_bar.value = 0
		shield_charge_bar.visible = false
	hull_label.text = "HULL   —"
	shield_label.text = "SHIELD —"
