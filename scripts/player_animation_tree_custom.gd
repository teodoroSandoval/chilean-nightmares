extends AnimationTree

@onready var cogito_player : CogitoPlayer = get_parent().get_parent()

@export var _3rd_person_camera : Node3D
@export var process_animations : bool = true

enum MoveState{
	UPRIGHT, CROUCHING, AIRBORNE
}
var current_move_state : MoveState = MoveState.UPRIGHT

enum ArmState{
	EMPTY, PISTOL,
}
var current_arm_state : ArmState = ArmState.EMPTY

var relative_velocity
# Relative velocity of player movement on the ground as a vector2, derived from the CharacterBody velocity vector 3.
var rel_velocity_xz : Vector2

func _physics_process(delta: float) -> void:
	# rig_node.rotation = cogito_player.body.rotation + Vector3(0,deg_to_rad(180),0)
	
	if process_animations:
		update_animations(delta)
	
func _get_8D_direction() -> Vector2: 
	var camera_forward = _3rd_person_camera.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	var player_forward = cogito_player._get_forward_direction()
	player_forward.y = 0
	player_forward = player_forward.normalized()
	# Calculate the angle between the camera's forward direction and the player's forward direction
	var angle = camera_forward.angle_to(player_forward)
	# Determine the sign of the angle based on the cross product
	var cross = camera_forward.cross(player_forward)
	var sign = 1.0
	if cross.y < 0:
		sign = -1.0

	angle *= sign

	# TODO: snap angle to 8 directions (N, NE, E, SE, S, SW, W, NW)
	var step_angle = PI / 4
	# var snapped_angle = round(angle / step_angle) * step_angle - (step_angle / 2 * sign)  # Offset by half a step to center the snapping
	var snapped_angle = round(angle / step_angle) * step_angle  # Offset by half a step to center the snapping
	
	var scalar = 1.0
	if _is_idle():
		scalar = 0.5
	elif _is_running():
		scalar = 2.0
	
	return Vector2(round(cos(snapped_angle)), round(sin(snapped_angle))) * scalar
func update_animations(_delta: float):

	match current_move_state:
		MoveState.UPRIGHT:
			rel_velocity_xz = _get_8D_direction()
			self.set("parameters/MainStateMachine/Upright/blend_position", rel_velocity_xz)
		MoveState.CROUCHING:
			rel_velocity_xz = _get_8D_direction()
			# relative_velocity = cogito_player.global_basis.inverse() * ((cogito_player.velocity * Vector3(1,0,1)) / cogito_player.CROUCHING_SPEED)
			# rel_velocity_xz = Vector2(relative_velocity.x, -relative_velocity.z)
			self.set("parameters/MainStateMachine/Crouched/blend_position", rel_velocity_xz)
		MoveState.AIRBORNE:
			rel_velocity_xz = _get_8D_direction()
			self.set("parameters/MainStateMachine/Jump/blend_position", rel_velocity_xz)
			self.set("parameters/MainStateMachine/Jump_Land/blend_position", rel_velocity_xz)

func _is_idle() -> bool:
	return cogito_player.velocity.length() < 0.1

func _is_running() -> bool:
	return current_move_state != MoveState.CROUCHING && cogito_player.velocity.length() >= 0.1 && cogito_player.velocity.length() <= cogito_player.SPRINTING_SPEED

func standing_up() -> void:
	if current_move_state != MoveState.UPRIGHT:
		current_move_state = MoveState.UPRIGHT
		
		var lower_body_state = self.get("parameters/MainStateMachine/playback")
		lower_body_state.travel("Upright")

func crouch_down() -> void:
	if current_move_state != MoveState.CROUCHING:
		current_move_state = MoveState.CROUCHING
		
		var lower_body_state = self.get("parameters/MainStateMachine/playback")
		lower_body_state.travel("Crouched")


func go_airborne() -> void:
	if current_move_state != MoveState.AIRBORNE:
		current_move_state = MoveState.AIRBORNE
		
		var lower_body_state = self.get("parameters/MainStateMachine/playback")
		lower_body_state.travel("Jump")
