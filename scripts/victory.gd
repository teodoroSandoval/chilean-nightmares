extends Control


@export var score_text: RichTextLabel
@export var sales_text: RichTextLabel
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func refresh_data(score: int, sales: int) -> void:
	score_text.text = tr("points") + ": %d" % score
	sales_text.text = tr("total sales") + ": $%d" % sales
