class_name WeaponAcquireConfirmOverlay
extends CanvasLayer

signal confirmed
signal cancelled

@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

var _accepting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)


func ask(title: String, prompt: String) -> void:
	title_label.text = title
	prompt_label.text = prompt
	visible = true
	_accepting = true
	confirm_button.grab_focus()


func close() -> void:
	_accepting = false
	visible = false


func _on_confirm() -> void:
	if not _accepting:
		return
	_accepting = false
	confirmed.emit()
	close()


func _on_cancel() -> void:
	if not _accepting:
		return
	_accepting = false
	cancelled.emit()
	close()
