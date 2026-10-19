extends CharacterBody3D
class_name PlayerManager

@export var walkSpeed: float = 5.0
@export var runSpeed: float = 10.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var baseCam: CameraController
@export var rotationSpeed: float = 1.0
@export var zoomSpeed: float = 1.0
@export var minZoom: float = 1
@export var maxZoom: float = 100
@export var flashlight: SpotLight3D
var camRotation: float = 0.0
var camZoom: float = 0.0
var is_movement_paused: bool = false
var is_dead: bool = false
var light_intensity: float = 1.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if flashlight:
		light_intensity = flashlight.light_energy
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if baseCam:
		
		if camRotation != 0:
			baseCam.rotation.y -= camRotation * delta * rotationSpeed

		if camZoom != 0:
			var scalarFactor = baseCam.size / minZoom
			baseCam.size = clamp(baseCam.size + (camZoom * delta * zoomSpeed * scalarFactor), minZoom, maxZoom)
		
		baseCam._set_camera_position()


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
	InputManager.gameplay_flashlight.completed.connect(_action_flashlight)


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
	InputManager.gameplay_flashlight.completed.disconnect(_action_flashlight)

func _on_look_input() -> void:
	var input_vector: Vector2 = InputManager.gameplay_look.value_axis_2d
	# TODO: rotate camera along y axis only
	camRotation = input_vector.x
	
	if InputManager.gameplay_lock_view.value_bool:
		var cam_forward: Vector3 = -baseCam.transform.basis.z.normalized()
		rotation.y = atan2(-cam_forward.x, -cam_forward.z)

func _on_movement_input() -> void:
	var input_vector: Vector2 = InputManager.gameplay_move.value_axis_2d
	if input_vector == Vector2.ZERO:
		velocity.x = 0
		velocity.z = 0
		return
	
	if baseCam:
		# Get the camera's forward direction
		var cam_forward: Vector3 = baseCam.global_transform.basis.z
		var cam_right: Vector3 = baseCam.global_transform.basis.x
		cam_forward.y = 0  # Keep movement in the horizontal plane
		cam_right.y = 0  # Keep movement in the horizontal plane
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()

		# Calculate the movement direction based on camera orientation
		var move_direction: Vector3 = (cam_forward * input_vector.y) + (cam_right * input_vector.x)
		# move_direction.y = 0  # Keep movement in the horizontal plane
		# move_direction = move_direction.normalized()

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
	
	if !InputManager.gameplay_lock_view.value_bool:
		rotation.y = atan2(-velocity.x, -velocity.z)

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
func _action_flashlight() -> void:
	print("Flashlight action triggered")
	# Handle flashlight toggle action
	if flashlight:
		flashlight.light_energy = light_intensity if flashlight.light_energy == 0.0 else 0.0
