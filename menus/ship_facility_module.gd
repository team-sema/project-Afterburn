class_name ShipFacilityModule
extends Panel

## 함선 시설 하나를 표시하는 재사용 UI 조각.
## 표시와 선택 통지만 하고, 시설 레벨이나 플레이어 스탯은 직접 바꾸지 않는다.

signal facility_clicked(facility_id: StringName)
## 마우스를 올렸을 때도 상세만 갱신한다 (강화 아님).
signal facility_hovered(facility_id: StringName)

enum UpgradeState {
	## 다음 레벨이 남아 있음
	UPGRADABLE,
	## 상한 도달
	MAXED,
	## 레벨 표가 Lv.1뿐 (강화 수치 미설정)
	UNSET,
}

const BORDER_IDLE := Color(0.16, 0.45, 0.68, 0.85)
const BORDER_UPGRADABLE := Color(0.28, 0.75, 1.0, 0.95)
const BORDER_SELECTED := Color(0.62, 0.97, 1.0, 1.0)
const FILL_IDLE := Color(0.02, 0.07, 0.14, 0.92)
const FILL_SELECTED := Color(0.05, 0.16, 0.28, 0.95)
const TEXT_ACTIVE := Color(0.82, 0.94, 1.0, 1.0)
const TEXT_DIM := Color(0.5, 0.68, 0.82, 0.9)
const ICON_IDLE := Color(0.45, 0.82, 1.0, 0.95)
const ICON_SELECTED := Color(0.85, 0.99, 1.0, 1.0)

@export var facility_id: StringName
## 함선 그림 위 연결점의 상대 위치 (ShipPanel이 연결선을 그릴 때 사용).
@export var hardpoint := Vector2(0.5, 0.5)

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var level_label: Label = $LevelLabel
@onready var effect_label: Label = $EffectLabel

var is_selected := false:
	set(value):
		is_selected = value
		_apply_style()

var _upgrade_state := UpgradeState.UNSET
var _is_hovered := false
var _style: StyleBoxFlat


func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.corner_radius_top_left = 3
	_style.corner_radius_top_right = 3
	_style.corner_radius_bottom_right = 3
	_style.corner_radius_bottom_left = 3
	_style.border_width_left = 1
	_style.border_width_top = 1
	_style.border_width_right = 1
	_style.border_width_bottom = 1
	add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_style()


func update_state(
	display_name: String,
	level: int,
	effect_text: String,
	upgrade_state: UpgradeState,
	icon: Texture2D = null,
) -> void:
	_upgrade_state = upgrade_state
	if not is_node_ready():
		return
	icon_rect.texture = icon
	name_label.text = display_name
	level_label.text = "Lv.%d" % level
	var marker := _upgrade_marker()
	effect_label.text = effect_text if marker.is_empty() else "%s %s" % [effect_text, marker]
	_apply_style()


## 레지스트리에 없는 시설 id가 씬에 남아 있을 때의 표시.
func show_unknown_facility() -> void:
	_upgrade_state = UpgradeState.UNSET
	if not is_node_ready():
		return
	icon_rect.texture = null
	name_label.text = String(facility_id)
	level_label.text = "—"
	effect_label.text = "—"
	_apply_style()


## 연결선이 닿는 칩 안쪽 모서리 (ShipPanel 좌표계).
func get_connector_point(toward_left: bool) -> Vector2:
	var edge_x := position.x if toward_left else position.x + size.x
	return Vector2(edge_x, position.y + size.y * 0.5)


func _upgrade_marker() -> String:
	match _upgrade_state:
		UpgradeState.UPGRADABLE:
			return "▲"
		UpgradeState.MAXED:
			return "MAX"
	return ""


func _apply_style() -> void:
	if not is_node_ready() or _style == null:
		return
	var border := BORDER_IDLE
	if _upgrade_state == UpgradeState.UPGRADABLE:
		border = BORDER_UPGRADABLE
	if is_selected:
		border = BORDER_SELECTED
	if _is_hovered:
		border = border.lerp(Color.WHITE, 0.25)
	_style.border_color = border
	_style.bg_color = FILL_SELECTED if is_selected else FILL_IDLE
	_style.shadow_size = 3 if is_selected else 0
	_style.shadow_color = Color(0.2, 0.8, 1.0, 0.25)
	icon_rect.self_modulate = ICON_SELECTED if is_selected else ICON_IDLE
	name_label.modulate = TEXT_ACTIVE
	level_label.modulate = TEXT_ACTIVE
	effect_label.modulate = TEXT_DIM if _upgrade_state == UpgradeState.UNSET else TEXT_ACTIVE


func _gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	facility_clicked.emit(facility_id)
	accept_event()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_style()
	facility_hovered.emit(facility_id)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_style()
