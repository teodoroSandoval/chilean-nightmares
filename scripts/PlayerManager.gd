extends CharacterBody3D
class_name PlayerManager

@export var walkSpeed: float = 5.0
@export var runSpeed: float = 10.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var phantomCam: PhantomCamera3D
@export var rotationSpeed: float = 1.0
@export var zoomSpeed: float = 1.0
@export var minZoom: float = 1
@export var maxZoom: float = 100
var camRotation: float = 0.0
var camZoom: float = 0.0
var is_movement_paused: bool = false
var is_dead: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if phantomCam:
		
		if camRotation != 0:
			phantomCam.rotation.y += camRotation * delta * rotationSpeed
			#TODO: compensate the camera position to keep the player in the center of the screen when rotating
			var offset: Vector3 = phantomCam.global_position - global_position
			var rotated_offset: Vector3 = offset.rotated(Vector3.UP, camRotation * delta * rotationSpeed)
			phantomCam.global_position = global_position + rotated_offset
			

		if camZoom != 0:
			phantomCam.get_camera_3d_resource().size = clamp(phantomCam.get_camera_3d_resource().size + camZoom * delta * zoomSpeed, minZoom, maxZoom)


func _physics_process(delta: float) -> void:
	# Aplicar gravedad si no está en el suelo
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Ejecutar el movimiento
	move_and_slide()

func enable_inputs() -> void:
	InputManager.gameplay_look.triggered.connect(_on_look_input)
	InputManager.gameplay_look.completed.connect(_on_look_input)
	InputManager.gameplay_move.triggered.connect(_on_movement_input)
	InputManager.gameplay_move.completed.connect(_on_movement_input)
	InputManager.gameplay_zoom.triggered.connect(_on_zoom_input)
	InputManager.gameplay_zoom.completed.connect(_on_zoom_input)
	InputManager.gameplay_grab.triggered.connect(_action_grab)
	InputManager.gameplay_throw.triggered.connect(_action_throw)
	InputManager.gameplay_jump.triggered.connect(_action_jump)


func disable_inputs() -> void:
	InputManager.gameplay_look.triggered.disconnect(_on_look_input)
	InputManager.gameplay_look.completed.disconnect(_on_look_input)
	InputManager.gameplay_move.triggered.disconnect(_on_movement_input)
	InputManager.gameplay_move.completed.disconnect(_on_movement_input)
	InputManager.gameplay_zoom.triggered.disconnect(_on_zoom_input)
	InputManager.gameplay_zoom.completed.disconnect(_on_zoom_input)
	InputManager.gameplay_grab.triggered.disconnect(_action_grab)
	InputManager.gameplay_throw.triggered.disconnect(_action_throw)
	InputManager.gameplay_jump.triggered.disconnect(_action_jump)

func _on_look_input() -> void:
	var input_vector: Vector2 = InputManager.gameplay_look.value_axis_2d
	# TODO: rotate camera along y axis only
	camRotation = input_vector.x

func _on_movement_input() -> void:
	var input_vector: Vector2 = InputManager.gameplay_move.value_axis_2d
	# TODO: move player with CharacterBody3D
	if input_vector == Vector2.ZERO:
		velocity.x = 0
		velocity.z = 0
		return
	
	if phantomCam:
		# Get the camera's forward direction
		var cam_forward: Vector3 = phantomCam.global_transform.basis.z.normalized()
		var cam_right: Vector3 = phantomCam.global_transform.basis.x.normalized()

		# Calculate the movement direction based on camera orientation
		var move_direction: Vector3 = (cam_forward * input_vector.y) + (cam_right * input_vector.x)
		move_direction.y = 0  # Keep movement in the horizontal plane
		move_direction = move_direction.normalized()

		var speed: float = walkSpeed
		if InputManager.gameplay_sprint.value_bool:
			speed = runSpeed

		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
	else:
		var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
		
		var speed: float = walkSpeed
		if InputManager.gameplay_sprint.value_bool:
			speed = runSpeed

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

func _on_zoom_input() -> void:
	var input_vector: float = InputManager.gameplay_zoom.value_axis_1d
	print("Zoom input value: ", input_vector)
	camZoom = input_vector

func _action_grab() -> void:
	# Handle grab action
	pass

func _action_throw() -> void:
	# Handle throw action
	pass

func _action_jump() -> void:
	# Handle jump action
	velocity.y = jump_velocity
func _pause_movement() -> void:
	is_movement_paused = true
	disable_inputs()
func _resume_movement() -> void:
	is_movement_paused = false
	enable_inputs()
