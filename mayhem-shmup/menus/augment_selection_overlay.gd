class_name AugmentSelectionOverlay
extends CanvasLayer

signal choice_selected(choice: Resource)

@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var choice_buttons: Array[Button] = [
	%ChoiceButton1,
	%ChoiceButton2,
	%ChoiceButton3,
]

var current_choices: Array = []


func _ready() -> void:
	for index in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
	visible = false


func show_choices(title: String, prompt: String, choices: Array) -> void:
	assert(not choices.is_empty(), "AugmentSelectionOverlay requires at least one choice.")
	assert(choices.size() <= choice_buttons.size(), "AugmentSelectionOverlay supports up to three choices.")
	current_choices = choices.duplicate()
	title_label.text = title
	prompt_label.text = prompt

	for index in choice_buttons.size():
		var button := choice_buttons[index]
		if index >= current_choices.size():
			button.visible = false
			continue

		var augment := current_choices[index] as Resource
		button.text = "%s\n%s" % [augment.get("display_name"), augment.get("description")]
		button.visible = true

	visible = true
	choice_buttons[0].grab_focus.call_deferred()


func hide_choices() -> void:
	visible = false
	current_choices.clear()


func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	choice_selected.emit(current_choices[index] as Resource)
