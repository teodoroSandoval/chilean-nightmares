extends GenericPopup
signal on_retry
signal on_to_title_screen

func _on_retry_pressed() -> void:
	on_retry.emit()
func _on_to_title_screen_pressed() -> void:
	on_to_title_screen.emit()