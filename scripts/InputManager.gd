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
@export var gameplay_lock_view:GUIDEAction
@export var gameplay_flashlight:GUIDEAction
@export var gameplay_action_primary:GUIDEAction
@export var gameplay_action_secondary:GUIDEAction
@export var gameplay_change_ammo_type:GUIDEAction
@export var gameplay_reload:GUIDEAction
@export var gameplay_quick_slot_1:GUIDEAction
@export var gameplay_quick_slot_2:GUIDEAction
@export var gameplay_quick_slot_3:GUIDEAction
@export var gameplay_quick_slot_4:GUIDEAction
@export var gameplay_quickslot_next_wieldable:GUIDEAction
@export var gameplay_quickslot_prev_wieldable:GUIDEAction

func _ready() -> void:
	controller_activated.triggered.connect(_on_device_activated.bind(GUIDEInput.DeviceType.JOY))
	keyboard_mouse_activated.triggered.connect(_on_device_activated.bind(GUIDEInput.DeviceType.KEYBOARD | GUIDEInput.DeviceType.MOUSE))
	touch_activated.triggered.connect(_on_device_activated.bind(GUIDEInput.DeviceType.TOUCH))
	ui_move.triggered.connect(_on_movement_input)
	ui_submit.triggered.connect(_on_submit_input)
	ui_cancel.triggered.connect(_on_cancel_input)
	pass
func _on_device_activated(type:GUIDEInput.DeviceType) -> void:
	_current_device_type = type
	on_device_changed.emit()
	
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
	# GUIDE.enable_mapping_context(mapping_context_ui)

func disable_input_UI() -> void:
	is_input_enabled_UI = false
	# GUIDE.disable_mapping_context(mapping_context_ui)

func enable_input_Gameplay() -> void:
	is_input_enabled_Gameplay = true
	# GUIDE.enable_mapping_context(mapping_context_gameplay)

func disable_input_Gameplay() -> void:
	is_input_enabled_Gameplay = false
	# GUIDE.disable_mapping_context(mapping_context_gameplay)

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