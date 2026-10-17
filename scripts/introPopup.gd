extends Control

@export var level_text: RichTextLabel
@export var objective_text: RichTextLabel
@export var highscore_text: RichTextLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass

func _set_texts(level, objective, highscore) -> void:
	level_text.text = "Nivel: " + str(level)
	objective_text.text = "Objetivo: " + str(objective) + " pts"
	highscore_text.text = "Récord: " + str(highscore)
