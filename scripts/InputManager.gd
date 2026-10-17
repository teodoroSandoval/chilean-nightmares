extends Node

signal on_device_changed

var is_input_enabled_UI: bool = false
var is_input_enabled_Gameplay: bool = false

var _current_device_type:GUIDEInput.DeviceType = GUIDEInput.DeviceType.MOUSE 

@export var mapping_context_gameplay:GUIDEMappingContext
@export var mapping_context_ui:GUIDEMappingContext

@export var controller_activated:GUIDEAction
@export var keyboard_mouse_activated:GUIDEAction
@export var touch_activated:GUIDEAction

@export var ui_submit:GUIDEAction
@export var ui_cancel:GUIDEAction
@export var ui_move:GUIDEAction

@export var gameplay_look:GUIDEAction
@export var gameplay_move:GUIDEAction
@export var gameplay_zoom:GUIDEAction
@export var gameplay_grab:GUIDEAction
@export var gameplay_throw:GUIDEAction
@export var gameplay_give_change:GUIDEAction
@export var gameplay_return_change:GUIDEAction
@export var gameplay_pause:GUIDEAction
@export var gameplay_inventory:GUIDEAction
@export var gameplay_free_look:GUIDEAction
@export var gameplay_jump:GUIDEAction
@export var gameplay_crouch:GUIDEAction
@export var gameplay_sprint:GUIDEAction
@export var gameplay_interact:GUIDEAction
@export var gameplay_interact2:GUIDEAction
# 

# var last_ui_input_vector: Vector2 = Vector2.ZERO
# var last_gameplay_input_vector: Vector2 = Vector2.ZERO
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# gameplay_move.changed.connect(_on_movement_input)
	controller_activated.triggered.connect(_on_device_activated.bind(GUIDEInput.DeviceType.JOY))
	keyboard_mouse_activated.triggered.connect(_on_device_activated.bind(GUIDEInput.DeviceType.KEYBOARD | GUIDEInput.DeviceType.MOUSE))
	# keyboard_mouse_activated.changed.connect(_on_device_activated.bind(GUIDEInput.DeviceType.KEYBOARD | GUIDEInput.DeviceType.MOUSE))
	touch_activated.triggered.connect(_on_device_activated.bind(GUIDEInput.DeviceType.TOUCH))
	ui_move.triggered.connect(_on_movement_input)
	ui_submit.triggered.connect(_on_submit_input)
	ui_cancel.triggered.connect(_on_cancel_input)
	# last_ui_input_vector = Vector2.ZERO
	# last_gameplay_input_vector = Vector2.ZERO
	# _setup_input_connections()
	pass
## Called when a certain device is activated. Depending on the mode
## updates the rendering to only show the last activated device.	
func _on_device_activated(type:GUIDEInput.DeviceType) -> void:
	_current_device_type = type
	on_device_changed.emit()
	
	# _formatter.formatting_options.input_filter = _filter_current_device_type
	
	# label._update_instructions()

# func _setup_input_connections() -> void:
	# fire.triggered.connect(func() -> void: gpu_particles_2d.emitting = true)
	# fire.completed.connect(func() -> void: gpu_particles_2d.emitting = false)
# func _input(event: InputEvent) -> void:
# 	if event is InputEventKey and (event as InputEventKey).pressed:
# 		if not (event as InputEventKey).echo: # non continuous inputs
# 			if(is_input_enabled_UI):
# 				# 1. Triggered ONCE exactly when the button is first pressed down
# 				if event.is_action_pressed("ui_Submit") && ui_submit.has_connections():
# 					ui_submit.emit()
# 				elif event.is_action_pressed("ui_Cancel") && on_ui_Cancel_pressed.has_connections():
# 					on_ui_Cancel_pressed.emit()
# 				elif ui_move.has_connections() and (event.is_action_pressed("ui_Up")  or event.is_action_pressed("ui_Down") or event.is_action_pressed("ui_Left") or event.is_action_pressed("ui_Right")):
# 					var current_ui_input_vector: Vector2 = Input.get_vector("ui_Left", "ui_Right", "ui_Up", "ui_Down")
# 					# if current_ui_input_vector != last_ui_input_vector:
# 					ui_move.emit(current_ui_input_vector)
# 					# last_ui_input_vector = current_ui_input_vector
# 			if(is_input_enabled_Gameplay):
# 				# 1. Triggered ONCE exactly when the button is first pressed down
# 				if gameplay_move.has_connections() and (event.is_action_pressed("gameplay_Up")  or event.is_action_pressed("gameplay_Down") or event.is_action_pressed("gameplay_Left") or event.is_action_pressed("gameplay_Right")):
# 					var current_gameplay_input_vector: Vector2 = Input.get_vector("gameplay_Left", "gameplay_Right", "gameplay_Up", "gameplay_Down")
# 					# if current_gameplay_input_vector != last_gameplay_input_vector:
# 					gameplay_move.emit(current_gameplay_input_vector)
# 					# last_gameplay_input_vector = current_gameplay_input_vector
# 				if event.is_action_pressed("gameplay_Grab") && gameplay_grab.has_connections():
# 					gameplay_grab.emit()
# 				elif event.is_action_pressed("gameplay_Throw") && gameplay_throw.has_connections():
# 					gameplay_throw.emit()
# 				elif event.is_action_pressed("gameplay_GiveChange") && gameplay_give_change.has_connections():
# 					gameplay_give_change.emit()
# 				elif event.is_action_pressed("gameplay_ReturnChange") && gameplay_return_change.has_connections():
# 					gameplay_return_change.emit()
# 				elif event.is_action_pressed("gameplay_Pause") && gameplay_pause.has_connections():
# 					gameplay_pause.emit()
		# var key : int = (event as InputEventKey).physical_keycode
		# _check_cheats(key)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _on_movement_input() -> void:
	var input_vector: Vector2 = InputManager.ui_move.value_axis_2d
	# Translate the GUIDE joystick movement back into a Native Godot Input Event
	var ev = InputEventAction.new()
	
	if input_vector.y < -0.5:
		ev.action = "ui_up"
	elif input_vector.y > 0.5:
		ev.action = "ui_down"
	elif input_vector.x < -0.5:
		ev.action = "ui_left"
	elif input_vector.x > 0.5:
		ev.action = "ui_right"
	if ev.action != "":
		ev.pressed = true
		Input.parse_input_event(ev) # Feeds it directly into Godot's UI system

func _on_submit_input() -> void:
	var ev = InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev) # Feeds it directly into Godot's UI system
	# Wait for 1 frame so Godot processes the press state
	await get_tree().process_frame
	
	# 2. Simulate the RELEASE
	var ev_release = InputEventAction.new()
	ev_release.action = "ui_accept"
	ev_release.pressed = false # Tells the UI the button was let go
	Input.parse_input_event(ev_release)	
	
func _on_cancel_input() -> void:
	var ev = InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev) # Feeds it directly into Godot's UI system
	# Wait for 1 frame so Godot processes the press state
	await get_tree().process_frame
	# 2. Simulate the RELEASE
	var ev_release = InputEventAction.new()
	ev_release.action = "ui_cancel"
	ev_release.pressed = false # Tells the UI the button was let go
	Input.parse_input_event(ev_release)	

func enable_input_UI() -> void:
	is_input_enabled_UI = true
	GUIDE.enable_mapping_context(mapping_context_ui)

func disable_input_UI() -> void:
	is_input_enabled_UI = false
	GUIDE.disable_mapping_context(mapping_context_ui)

func enable_input_Gameplay() -> void:
	is_input_enabled_Gameplay = true
	GUIDE.enable_mapping_context(mapping_context_gameplay)

func disable_input_Gameplay() -> void:
	is_input_enabled_Gameplay = false
	GUIDE.disable_mapping_context(mapping_context_gameplay)

func switch_to_UI() -> void:
	print("switching to UI")
	disable_input_Gameplay()
	enable_input_UI()
func switch_to_Gameplay() -> void:
	print("switching to gameplay")
	disable_input_UI()
	enable_input_Gameplay()
func disable_All() -> void:
	print("disabling all input")
	disable_input_UI()
	disable_input_Gameplay()

func _hide_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _show_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE