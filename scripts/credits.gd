extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		var key : int = (event as InputEventKey).physical_keycode

		if key == KEY_ENTER or key == KEY_SPACE:
			_to_title_screen()

func _to_title_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")