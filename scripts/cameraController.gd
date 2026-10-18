
extends Camera3D
class_name CameraController

@export var player: PlayerManager
@export var followDistance: float = 10.0
@export var lookAngle: float = 30.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_set_camera_position()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# _set_camera_position()
	pass

func _physics_process(delta: float) -> void:
	# _set_camera_position()
	pass

func _set_camera_position() -> void:
	rotation_degrees.x = -lookAngle
	if player:
		var player_position: Vector3 = player.global_position
		var camera_forward: Vector3 = -transform.basis.z.normalized()
		var offset: Vector3 = camera_forward * -followDistance
		global_position = player_position + offset
