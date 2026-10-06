class_name UiFocus
extends RefCounted

## 메뉴 계열 화면의 공용 포커스 연결. 규칙: docs/design/README.md (UI 입력 원칙)


## 세로 목록을 위/아래(Tab 포함) 순환으로 연결한다. 슬라이더가 아닌 항목은 좌/우로 포커스가 새지 않게 막는다.
static func link_vertical_loop(controls: Array) -> void:
	var count := controls.size()
	for i in count:
		var control: Control = controls[i]
		control.focus_neighbor_top = control.get_path_to(controls[(i - 1 + count) % count])
		control.focus_neighbor_bottom = control.get_path_to(controls[(i + 1) % count])
		control.focus_previous = control.focus_neighbor_top
		control.focus_next = control.focus_neighbor_bottom
		if not control is Range:
			control.focus_neighbor_left = ^"."
			control.focus_neighbor_right = ^"."


## 포커스를 잃은 상태에서 방향·확인 입력이 오면 true. 호출 측이 기본 항목에 포커스를 복구한다.
static func needs_focus_restore(viewport: Viewport, event: InputEvent) -> bool:
	if viewport.gui_get_focus_owner() != null:
		return false
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept"]:
		if event.is_action_pressed(action):
			return true
	return false
