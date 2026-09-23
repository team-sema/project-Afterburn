class_name ShipStatusHud
extends VBoxContainer

## 전투 중 실드 게이지. 함선의 상태를 읽어 표시만 하고 값을 바꾸지 않는다.
## 선체 HP는 항상 1이라 HUD에 두지 않는다. STATUS 패널의 모듈 슬롯과는 다른 정보다.

@export var ship: Node2D

@onready var shield_label: Label = %ShieldLabel
@onready var shield_bar: ProgressBar = %ShieldBar
@onready var shield_charge_bar: ProgressBar = %ShieldChargeBar

var _shield: ShieldComponent


func _ready() -> void:
	# 함선은 게임플레이 서브씬에 있어 한 프레임 뒤에 붙는다.
	call_deferred("_bind_ship")


func _bind_ship() -> void:
	if not is_instance_valid(ship):
		_show_offline()
		return
	_shield = ship.get_node_or_null("ShieldComponent") as ShieldComponent
	if _shield != null and not _shield.shield_changed.is_connected(_on_shield_changed):
		_shield.shield_changed.connect(_on_shield_changed)
	if _shield != null and not _shield.charge_changed.is_connected(_on_charge_changed):
		_shield.charge_changed.connect(_on_charge_changed)
	ship.tree_exited.connect(_show_offline)
	refresh()


func refresh() -> void:
	_refresh_shield()
	_refresh_charge()


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


func _on_shield_changed(_current_shield: int, _max_shield: int) -> void:
	_refresh_shield()


func _on_charge_changed(_progress: float) -> void:
	_refresh_charge()


func _show_offline() -> void:
	_shield = null
	shield_bar.value = 0
	if shield_charge_bar != null:
		shield_charge_bar.value = 0
		shield_charge_bar.visible = false
	shield_label.text = "SHIELD —"
