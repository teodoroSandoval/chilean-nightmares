extends Control

@export var settings_popup: Node
@export var collection_popup: Node
@export var first_selected_button: Node

# Called when the node enters the scene tree for the first time.
func _ready():
	%ButtonPlayStory.pressed.connect(play_story_mode)
	%ButtonPlayInfnite.pressed.connect(play_infinite_mode)
	%ButtonPlayArcade.pressed.connect(play_arcade_mode)
	%ButtonPlayVersus.pressed.connect(play_versus_mode)
	# %ButtonCollection.pressed.connect(collection)
	%ButtonSettings.pressed.connect(settings)
	%ButtonQuit.pressed.connect(quit)
	InputManager.switch_to_UI()
	if first_selected_button:
		first_selected_button.grab_focus()

# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass
func play_story_mode():
	GameManager._game_mode = GameManager.GameMode.STORY_MODE
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func play_infinite_mode():
	GameManager._game_mode = GameManager.GameMode.INFINITE_MODE
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func play_arcade_mode():
	GameManager._game_mode = GameManager.GameMode.ARCADE_MODE
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func play_versus_mode():
	GameManager._game_mode = GameManager.GameMode.VERSUS_MODE
	get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func collection():
	collection_popup.show()
	
func settings():
	settings_popup.show()
	
func quit():
	get_tree().quit()
