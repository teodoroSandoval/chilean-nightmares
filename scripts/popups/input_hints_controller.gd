class_name InputHintsController
extends Control

## You can override this class to add buttons to your pause menu
## look at the function open_options_menu for an example of showing a submenu


# Signals
signal input_hints_closed
signal input_hints_opened

#region Variables
# @export var nodes_to_focus: Array[Control]
@export var sound_hover : AudioStream
@export var sound_click : AudioStream
@export var empty_slot_texture : Texture

var playback : AudioStreamPlaybackPolyphonic
var temp_screenshot : Image

@onready var close_button: Button = $ColorRect/CloseButton
#endregion


func _enter_tree() -> void:
	# Create an audio player
	var player = AudioStreamPlayer.new()
	add_child(player)

	# Create a polyphonic stream so we can play sounds directly from it
	var stream = AudioStreamPolyphonic.new()
	stream.polyphony = 32
	player.stream = stream
	player.play()
	# Get the polyphonic playback stream to play sounds
	playback = player.get_stream_playback()

	# get_tree().node_added.connect(_on_node_added)


# func _on_node_added(node:Node) -> void:
# 	if node is Button:
		# If the added node is a button we connect to its mouse_entered and pressed signals
		# and play a sound
		# node.mouse_entered.connect(_play_hover)
		# node.focus_entered.connect(_play_hover)
		# node.pressed.connect(_play_pressed)


# func _play_hover() -> void:
# 	playback.play_stream(sound_hover, 0, 0, 1)


# func _play_pressed() -> void:
# 	playback.play_stream(sound_click, 0, 0, 1)


func _ready() -> void:
	#Stops game and shows pause menu
	get_tree().paused = true
	input_hints_opened.emit()
	
	InputHelper.device_changed.connect(_on_input_device_changed)
		
	temp_screenshot = CogitoSceneManager.grab_screenshot(CogitoGlobals.screenshot_scale)
	# nodes_to_focus[0].grab_focus.call_deferred()
	
	InputRouter.push(on_input)
	if InputHelper.device_index == -1:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		
	# close_button.grab_focus.call_deferred()

func _exit_tree() -> void:
	InputHelper.device_changed.disconnect(_on_input_device_changed)

func on_input(event):
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		accept_event()
		close_input_hints()

func close_input_hints():
	get_tree().paused = false
	InputRouter.pop()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	input_hints_closed.emit()
	queue_free()


func _on_close_button_pressed():
	close_input_hints()

func _on_input_device_changed(device: String, device_index: int) -> void:
	Input.mouse_mode = Input.MouseMode.MOUSE_MODE_VISIBLE if device_index < 0 else Input.MouseMode.MOUSE_MODE_CAPTURED
