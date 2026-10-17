extends Control
signal resume

@export var settings_popup: Control
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass

func _resume_game() -> void:
	owner._resume_game()
	emit_signal("resume")
func _to_title_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
func _show_settings() -> void:
	settings_popup.show()
func _hide_settings() -> void:
	settings_popup.hide()
func _save_and_quit() -> void:
	get_tree().quit()
