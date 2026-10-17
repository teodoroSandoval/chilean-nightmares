extends Control
class_name GenericPopup

@export var close_button: Button
@export var first_selected_button: Node
signal on_close_pressed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if close_button:
		close_button.pressed.connect(_close_popup)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_visibility_changed() -> void:
	if visible:
		enable_inputs()
	else:
		disable_inputs()
func enable_inputs() -> void:
	if first_selected_button:
		first_selected_button.grab_focus()

func disable_inputs() -> void:
	pass

func _close_popup() -> void:
	hide()
	on_close_pressed.emit()