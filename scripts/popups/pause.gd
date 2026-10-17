extends GenericPopup
signal on_resume_game
signal on_to_title_screen
signal on_show_settings
signal on_quit_game

func _resume_game() -> void:
	on_resume_game.emit()
func _to_title_screen() -> void:
	on_to_title_screen.emit()
func _show_settings() -> void:
	on_show_settings.emit()
# func _hide_settings() -> void:
# 	settings_popup.hide()
func _save_and_quit() -> void:
	on_quit_game.emit()