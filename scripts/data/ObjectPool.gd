extends Node
class_name ObjectPool

@export var min_size: int = 0
@export var base_node: Node
@export var instaced_objects: Array[Node]
@export var active_objects: Array[Node]

func _ready() -> void:
	for i in range(min_size):
		var instance = base_node.duplicate()
		instance.hide()
		instaced_objects.append(instance)
		add_child(instance)

func get_instance() -> Node:
	for instance in instaced_objects:
		if not instance.is_visible():
			instance.show()
			active_objects.append(instance)
			return instance
	var instance = base_node.duplicate()
	instance.hide()
	instaced_objects.append(instance)
	add_child(instance)
	instance.show()
	active_objects.append(instance)
	return instance

func return_instance(instance: Node) -> void:
	instance.hide()
	if instance in active_objects:
		active_objects.erase(instance)
	else:
		if instance not in instaced_objects: 
			instance.queue_free()
	
# func release_instance(instance: Node) -> void:
# 	if instance in active_objects:
# 		active_objects.erase(instance)
# 		instance.hide()
# 		if instance in instaced_objects:
# 			instaced_objects.erase(instance)
