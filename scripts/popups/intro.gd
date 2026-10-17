extends GenericPopup
signal on_continue

func _on_continue_pressed() -> void:
	on_continue.emit()