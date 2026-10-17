extends Resource
class_name RoadsData
@export var imported_nodes: Array[OsmNodeRecord] = []
@export var imported_roads: Array[OsmRoadRecord] = []
@export var node_by_id: Dictionary[int, OsmNodeRecord] = {}
