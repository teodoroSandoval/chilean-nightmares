extends Area3D
class_name BuildingTrigger

## If true, the player HUD will be hidden while playing the cutscene.
@export var objects_inside : Array[Node]
@export var objects_outside : Array[Node]
# var players_inside : Array[Node]

var player_reference : CogitoPlayer
var has_been_triggered : bool = false #Used to avoid double-triggering.

func _ready() -> void:
	add_to_group("save_object_state")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# func on_input(event: InputEvent) -> void:
# 	if event.is_action_pressed("ui_cancel") and allow_cancel:
# 		finish_cutscene()


func _on_body_entered(body: Node3D):
	if !body.is_in_group("Player"):
		return
	
	player_reference = body
	show_interior()


func _on_body_exited(body: Node3D):
	if !body.is_in_group("Player"):
		return
	
	player_reference = null
	show_exterior()

func show_interior() -> void:
	for object_in in objects_inside:
		object_in.show()
	for object_out in objects_outside:
		object_out.hide()

func show_exterior() -> void:
	for object_in in objects_inside:
		object_in.hide()
	for object_out in objects_outside:
		object_out.show()

func set_state() -> void:
	pass
	
func save():
	var state_dict = {
		"node_path" : self.get_path(),
		"has_been_triggered" : has_been_triggered,
		"pos_x" : position.x,
		"pos_y" : position.y,
		"pos_z" : position.z,
		"rot_x" : rotation.x,
		"rot_y" : rotation.y,
		"rot_z" : rotation.z,
		
	}
	return state_dict
