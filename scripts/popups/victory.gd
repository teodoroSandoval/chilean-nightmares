extends GenericPopup
signal on_continue
signal on_to_title_screen
# @export var continue_button: Button
@export var score_text: RichTextLabel
@export var sales_text: RichTextLabel

func refresh_data(score: int, sales: int) -> void:
	score_text.text = tr("points") + ": %d" % score
	sales_text.text = tr("total sales") + ": $%d" % sales

func _on_continue_pressed() -> void:
	on_continue.emit()
func _on_to_title_screen_pressed() -> void:
	on_to_title_screen.emit()