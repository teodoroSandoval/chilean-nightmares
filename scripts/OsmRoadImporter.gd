@tool
extends Node3D
class_name OsmRoadImporter

@export_group("Input")
@export_file("*.osm") var osm_file_path = "res://planet_-68.375,-23.023_-68.03,-22.815.osm"
@export var debug_mesh_instance: MeshInstance3D
@export_group("Import Options")
@export var import_on_start = false
@export var meters_to_godot = 0.01
@export var max_operations: int = 100
@export var transformation_reference: Node3D
@export var road_nodes_base: Node3D
@export_tool_button("Import now") var import_now_action: Callable = import_now
@export_tool_button("Align to surface") var align_to_surface_action: Callable = _align_nodes_to_surface
@export_tool_button("Generate roads") var generate_roads_action: Callable = generate_roads
@export_group("Projection")
@export var use_bounds_center_as_origin = true
@export var manual_origin_latitude = 0.0
@export var manual_origin_longitude = 0.0
@export_flags_3d_physics var terrain_collision_mask = 1
@export_group("Debug Preview")
@export var draw_roads = true
@export var draw_unsorted_roads: bool  = true
@export var draw_buildings: bool  = true
@export var draw_waterway: bool  = true
@export var draw_node: bool  = true
@export var draw_amenity: bool  = true
@export var draw_natural: bool = true
@export var draw_landuse: bool  = true
@export var draw_railway: bool  = true
@export var draw_leisure: bool  = true
@export var draw_barriers: bool  = true
@export var draw_boundary: bool  = true
@export var draw_man_made: bool  = true
@export_flags("Secondary", "Tertiary", "Trunk Link", "Path", "Residential", "Unclassified", "Trunk", "Service", "Footway", "Pedestrian", "Living Street", "Track", "Secondary Link", "Steps") var highway_gizmo_flags : int = OsmRoadRecord.HighwayType.NONE
@export_flags("Asphalt", "Compacted", "Unpaved", "Ground", "Dirt", "Paving Stones", "Paved", "Gravel", "Artificial Turf", "Sand", "Concrete", "Metal", "US") var surface_gizmo_flags : int = OsmRoadRecord.SurfaceType.NONE
@export var road_debug_color = Color(0.15, 0.9, 1.0, 1.0)
@export var debug_height = 0.2
@export_group("Actions")
@export var print_highway_types = false
var print_surface_types = false

@export_tool_button("Refresh debug mesh") var rebuild_debug_preview_action: Callable = _rebuild_debug_preview

# @export var imported_nodes: Array[OsmNodeRecord] = []
# @export var imported_roads: Array[OsmRoadRecord] = []
# @export var _node_by_id: Dictionary[int, OsmNodeRecord] = {}
@export var roads_data: RoadsData
var _has_bounds = false
var _bounds = Vector4()

func _ready() -> void:
    if import_on_start:
        import_osm_roads()
        if Engine.is_editor_hint():
            import_on_start = false
func import_now() -> void:
        import_osm_roads()

func _process(_delta: float) -> void:
    if print_highway_types:
        print_highway_types = false
        _print_types("Highway", "highway_type")
    if print_surface_types:
        print_surface_types = false
        _print_types("Surface", "surface_type")

func import_osm_roads() -> void:
    roads_data.imported_nodes.clear()
    roads_data.imported_roads.clear()
    roads_data._node_by_id.clear()
    roads_data._has_bounds = false
    var parser = XMLParser.new()
    var error = parser.open(osm_file_path)
    if error != OK:
        push_error("OSM import failed: could not open %s (%s)." % [osm_file_path, error_string(error)])
        return
    var raw_nodes: Dictionary[int, Vector2] = {}
    var raw_roads: Array[OsmRoadRecord] = []
    _parse_osm_xml(parser, raw_nodes, raw_roads)
    if raw_roads.is_empty():
        push_warning("OSM import finished, but no ways with two or more nodes were found.")
        return
    
    _build_road_data(raw_nodes, raw_roads)
    _rebuild_debug_preview()
    print("OSM import finished. Roads: %d, Nodes: %d" % [roads_data.imported_roads.size(), roads_data.imported_nodes.size()])

func _parse_osm_xml(parser: XMLParser, raw_nodes: Dictionary[int, Vector2], raw_roads: Array[OsmRoadRecord]) -> void:
    while parser.read() == OK:
        if parser.get_node_type() != XMLParser.NODE_ELEMENT:
            continue
        match parser.get_node_name():
            "bounds": _parse_bounds(parser)
            "node":
                var id = _integer_attribute(parser, "id")
                var latitude = _float_attribute(parser, "lat")
                var longitude = _float_attribute(parser, "lon")
                if id != null and latitude != null and longitude != null:
                    raw_nodes[id] = Vector2(latitude, longitude)
            "way":
                var road = _parse_way(parser)
                if road != null and not road.is_area and road.node_ids.size() > 1:
                    raw_roads.append(road)

func _parse_bounds(parser: XMLParser) -> void:
    var min_latitude = _float_attribute(parser, "minlat")
    var min_longitude = _float_attribute(parser, "minlon")
    var max_latitude = _float_attribute(parser, "maxlat")
    var max_longitude = _float_attribute(parser, "maxlon")
    if min_latitude == null or min_longitude == null or max_latitude == null or max_longitude == null:
        return
    _bounds = Vector4(min_latitude, min_longitude, max_latitude, max_longitude)
    _has_bounds = true

func _parse_way(parser: XMLParser) -> OsmRoadRecord:
    var id = _integer_attribute(parser, "id")
    if id == null:
        return null
    var road = OsmRoadRecord.new()
    road.id = id
    var read_state = parser.read()
    # var is_empty = parser.is_empty()
    while read_state == OK:
        if parser.get_node_type() == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "way":
            break
        if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "nd":
            var node_id = _integer_attribute(parser, "ref")
            if node_id != null:
                road.node_ids.append(node_id)
        elif parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "tag":
            _parse_way_tag(parser, road)
        read_state = parser.read()
    return road

func _parse_way_tag(parser: XMLParser, road: OsmRoadRecord) -> void:
    var key = parser.get_named_attribute_value("k")
    var value = parser.get_named_attribute_value("v")
    road.tags[key] = value
    match key:
        "area": road.is_area = _is_true(value)
        "oneway": road.one_way = _is_true(value)
        "name": road.name = value
        "official_name": road.official_name = value
        "alt_name": road.alternate_name = value
        "lanes": road.lanes = value.to_int() if value.is_valid_int() else road.lanes
        "lit": road.lit = _is_true(value)
        "highway":
            road.is_highway = true
            road.highway_type = _highway_type(value)
        "surface":
            road.surface_type = _surface_type(value)
        "building": 
            road.is_building = true
            road.building_type = value
        "waterway": 
            road.is_waterway = true
            road.waterway_type = value
        "railway": 
            road.is_railway = true
            road.railway_type = value
        "landuse": 
            road.is_landuse = true
            road.landuse_type = value
        "natural": 
            road.is_natural = true
            road.natural_type = value
        "amenity":
            road.is_amenity = true
            road.amenity_type = value
        "leisure":
            road.is_leisure = true
            road.leisure_type = value
        "barrier":
            road.is_barrier = true
            road.barrier_type = value
        "boundary":
            road.is_boundary = true
            road.boundary_type = value
        "man_made":
            road.is_man_made = true
            road.man_made_type = value

func _build_road_data(raw_nodes: Dictionary[int, Vector2], roads: Array[OsmRoadRecord]) -> void:
    var origin = _origin()
    roads_data.imported_roads.assign(roads)
    for road in roads_data.imported_roads:
        for id in road.node_ids:
            if not raw_nodes.has(id) or roads_data.node_by_id.has(id):
                continue
            var coordinate: Vector2 = raw_nodes[id]
            var record = OsmNodeRecord.new()
            record.id = id
            record.latitude = coordinate.x
            record.longitude = coordinate.y
            record.world_position = _to_world(coordinate.x, coordinate.y, origin.x, origin.y)
            roads_data.node_by_id[id] = record
            roads_data.imported_nodes.append(record)

func _origin() -> Vector2:
    if use_bounds_center_as_origin and roads_data._has_bounds:
        return Vector2((roads_data._bounds.x + roads_data._bounds.z) * 0.5, (roads_data._bounds.y + roads_data._bounds.w) * 0.5)
    return Vector2(manual_origin_latitude, manual_origin_longitude)

func _to_world(latitude: float, longitude: float, origin_latitude: float, origin_longitude: float) -> Vector3:
    var x_meters = (longitude - origin_longitude) * 111320.0 * cos(deg_to_rad(origin_latitude))
    var z_meters = (latitude - origin_latitude) * 110540.0
    var final_x_meters = x_meters * meters_to_godot
    var final_z_meters = z_meters * meters_to_godot
    if transformation_reference != null:
        return transformation_reference.to_global(Vector3(final_x_meters, 0.0, final_z_meters))
    else:
        return to_global(Vector3(final_x_meters, 0.0, final_z_meters))

func _rebuild_debug_preview() -> void:
    if debug_mesh_instance == null:
        debug_mesh_instance = MeshInstance3D.new()
        debug_mesh_instance.name = "OsmRoadDebugPreview"
        debug_mesh_instance.top_level = true
        add_child(debug_mesh_instance)
        debug_mesh_instance.owner = owner
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    for road in roads_data.imported_roads:
        if not _should_draw_main(road):
            continue
        if not _should_draw_highway_type(road.highway_type):
            continue
        if not _should_draw_surface_type(road.surface_type):
            continue
        for index in range(1, road.node_ids.size()):
            var from: OsmNodeRecord = roads_data.node_by_id.get(road.node_ids[index - 1])
            var to: OsmNodeRecord = roads_data.node_by_id.get(road.node_ids[index])
            if from != null and to != null:
                mesh.surface_add_vertex(from.world_position + Vector3.UP * debug_height)
                mesh.surface_add_vertex(to.world_position + Vector3.UP * debug_height)
    mesh.surface_end()
    debug_mesh_instance.mesh = mesh
    var material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = road_debug_color
    debug_mesh_instance.material_override = material

func _should_draw_main(road: OsmRoadRecord) -> bool:
    if road.is_amenity:
        return draw_amenity
    if road.is_boundary:
        return draw_boundary
    if road.is_barrier:
        return draw_barriers
    if road.is_highway:
        return draw_roads if road.highway_type != OsmRoadRecord.HighwayType.NONE else draw_unsorted_roads
    if road.is_building:
        return draw_buildings
    if road.is_waterway:
        return draw_waterway
    if road.is_railway:
        return draw_railway
    if road.is_landuse:
        return draw_landuse
    if road.is_natural:
        return draw_natural
    if road.is_leisure:
        return draw_leisure
    if road.is_man_made:
        return draw_man_made
    return false
func _should_draw_highway_type(_type: OsmRoadRecord.HighwayType) -> bool:
    return (_type & highway_gizmo_flags) != 0
func _should_draw_surface_type(_type: OsmRoadRecord.SurfaceType) -> bool:
    return (_type & surface_gizmo_flags) != 0
func _align_nodes_to_surface() -> void:
    if roads_data.imported_nodes.is_empty() or not is_inside_tree():
        push_warning("No imported nodes are available to align to the surface.")
        return
    for record in roads_data.imported_nodes:
        var main_height = get_height_on_main_terrain(record.world_position)
        if main_height != null:
            record.world_position.y = main_height
        else:
            var far_height = get_height_on_far_terrain(record.world_position)
            if far_height != null:
                # print("height: %f" % far_height)
                record.world_position.y = far_height
            # else:
                # print("No hit for id %d" % record.id)
    
    _rebuild_debug_preview()
func get_height_on_main_terrain(origin: Vector3) -> Variant:
    var terrain_manager: TerrainLoadManager = %Main_Terrain.find_child("Terrains_LevelA") as TerrainLoadManager
    if terrain_manager == null:
        return null
    return terrain_manager.sample_height_at_position(origin)
    # return null

func get_height_on_far_terrain(origin: Vector3) -> Variant:
    var children_names = ["mapa_san-pedro-de-atacama_rez_B", "mapa_san-pedro-de-atacama_rez_C", "mapa_san-pedro-de-atacama_rez_D", "mapa_san-pedro-de-atacama_rez_E"]
    for _name in children_names:
        var terrain_manager: TerrainMeshTools = %Far_Terrain.find_child(_name) as TerrainMeshTools
        if terrain_manager != null:
            var height = terrain_manager.sample_height_at_position(origin)
            if height != null:
                return height
    return null

func _print_types(label: String, property: String) -> void:
    var found = {}
    for road in roads_data.imported_roads:
        found[road.get(property)] = true
    for type in found:
        print("%s type: %s" % [label, type])

func _integer_attribute(parser: XMLParser, attribute: String) -> Variant:
    var value = parser.get_named_attribute_value(attribute)
    return value.to_int() if value.is_valid_int() else 0

func _float_attribute(parser: XMLParser, attribute: String) -> Variant:
    var value = parser.get_named_attribute_value(attribute)
    return value.to_float() if value.is_valid_float() else 0.0

func _is_true(value: String) -> bool:
    return value.to_lower() in ["yes", "true", "1"]

func _highway_type(value: String) -> OsmRoadRecord.HighwayType:
    var types = {"secondary": OsmRoadRecord.HighwayType.SECONDARY, "tertiary": OsmRoadRecord.HighwayType.TERTIARY, "trunk_link": OsmRoadRecord.HighwayType.TRUNK_LINK, "path": OsmRoadRecord.HighwayType.PATH, "residential": OsmRoadRecord.HighwayType.RESIDENTIAL, "unclassified": OsmRoadRecord.HighwayType.UNCLASSIFIED, "trunk": OsmRoadRecord.HighwayType.TRUNK, "service": OsmRoadRecord.HighwayType.SERVICE, "footway": OsmRoadRecord.HighwayType.FOOTWAY, "pedestrian": OsmRoadRecord.HighwayType.PEDESTRIAN, "living_street": OsmRoadRecord.HighwayType.LIVING_STREET, "track": OsmRoadRecord.HighwayType.TRACK, "secondary_link": OsmRoadRecord.HighwayType.SECONDARY_LINK, "steps": OsmRoadRecord.HighwayType.STEPS}
    return types.get(value.to_lower(), OsmRoadRecord.HighwayType.NONE)

func _surface_type(value: String) -> OsmRoadRecord.SurfaceType:
    var types = {"asphalt": OsmRoadRecord.SurfaceType.ASPHALT, "compacted": OsmRoadRecord.SurfaceType.COMPACTED, "unpaved": OsmRoadRecord.SurfaceType.UNPAVED, "ground": OsmRoadRecord.SurfaceType.GROUND, "dirt": OsmRoadRecord.SurfaceType.DIRT, "paving_stones": OsmRoadRecord.SurfaceType.PAVING_STONES, "paved": OsmRoadRecord.SurfaceType.PAVED, "gravel": OsmRoadRecord.SurfaceType.GRAVEL, "artificial_turf": OsmRoadRecord.SurfaceType.ARTIFICIAL_TURF, "sand": OsmRoadRecord.SurfaceType.SAND, "concrete": OsmRoadRecord.SurfaceType.CONCRETE, "metal": OsmRoadRecord.SurfaceType.METAL, "us": OsmRoadRecord.SurfaceType.US}
    return types.get(value.to_lower(), OsmRoadRecord.SurfaceType.NONE)
func generate_roads() -> void:
    if roads_data.imported_roads.is_empty() or roads_data.imported_nodes.is_empty():
        push_warning("No imported roads or nodes are available to generate.")
        return
    
    road_nodes_base.update_edges()
    road_nodes_base.update_lane_seg_connections()
    road_nodes_base.setup_road_container()
    for road in roads_data.imported_roads:
        if not _should_draw_main(road):
            continue
        if not _should_draw_highway_type(road.highway_type):
            continue
        if not _should_draw_surface_type(road.surface_type):
            continue

        generate_road_segment(road)
        road_nodes_base._needs_refresh = true
        # break
## Add a new roadpoint in a given direction
func generate_road_segment(road_record: OsmRoadRecord) -> void:
    pass
    # for index in range(0, road_record.node_ids.size()):
    #     var node_A: OsmNodeRecord =  getNode(road_record.node_ids[index])
        # var node_B: OsmNodeRecord =  getNode(road_record.node_ids[index])

        # var new_rp_A := add_or_get_rp(node_A, road_record)
        # var new_rp_B := add_or_get_rp(node_B, road_record)

        # Finally, connect them together
        # var res = new_rp_A.connect_roadpoint(RoadPoint.LaneDir.FORWARD, new_rp_B, RoadPoint.LaneDir.REVERSE)
        # if res != true:
        #     print("Failed to connect RoadPoint")
        #     return
# func add_or_get_rp(node: OsmNodeRecord, road_record: OsmRoadRecord) -> RoadPoint:

#     var new_rp : RoadPoint = road_nodes_base.get_node_or_null(str(node.id))
#     if new_rp == null:
#         print("creating RoadPoint")
#         new_rp = RoadPoint.new()
#         road_nodes_base.add_child(new_rp)
#         new_rp.set_owner(get_tree().get_edited_scene_root())
#         new_rp.name = str(node.id)
#     else:
#         print("reusing RoadPoint")
#         print(new_rp)

#     new_rp.transform.origin = node.world_position
#     new_rp.auto_lanes = false
#     new_rp.lane_width = 4.0
#     new_rp.shoulder_width_l = 2.0
#     new_rp.shoulder_width_r = 2.0
#     new_rp.gutter_profile.x = 2.0
#     new_rp.gutter_profile.y = -0.5
#     new_rp.create_geo = true
#     new_rp._last_update_ms = 500
#     new_rp.alignment = RoadPoint.Alignment.DIVIDER
#     new_rp.underside_thickness = -1.0
#     new_rp.flatten_terrain = true

#     # new_rp.traffic_dir = ref_road_point.traffic_dir.duplicate(true)
#     # new_rp.lanes = ref_road_point.lanes.duplicate(true)

#     new_rp.traffic_dir=[
#         RoadPoint.LaneDir.REVERSE,
#         RoadPoint.LaneDir.FORWARD
#     ]
#     new_rp.lanes=[
#         RoadPoint.LaneType.SLOW,
#         RoadPoint.LaneType.SLOW
#     ]

#     # for idx in range(randi_range(1, 4)):
#     #     new_rp.traffic_dir.append(RoadPoint.LaneDir.REVERSE)
#     #     new_rp.lanes.append(RoadPoint.LaneType.SLOW)
#     # for idx in range(randi_range(0, 2)):
#     #     new_rp.traffic_dir.append(RoadPoint.LaneDir.REVERSE)
#     #     new_rp.lanes.append(RoadPoint.LaneType.FAST)
#     # for idx in range(randi_range(0, 2)):
#     #     new_rp.traffic_dir.append(RoadPoint.LaneDir.FORWARD)
#     #     new_rp.lanes.append(RoadPoint.LaneType.FAST)
#     # for idx in range(randi_range(1, 4)):
#     #     new_rp.traffic_dir.append(RoadPoint.LaneDir.FORWARD)
#     #     new_rp.lanes.append(RoadPoint.LaneType.SLOW)

#     # Placement of a new roadpoint with interval no larger than buffer,
#     # to avoid flicker removal/adding with the culling system

#     # Randomly rotate the offset vector slightly
#     # var _transform := new_rp.transform
#     # var angle_range := 30 # Random angle rotation range
#     # var random_angle: float = randf_range(-angle_range / 2.0, angle_range / 2.0) # Generate a random angle within the range
#     # var rotation_axis := Vector3.UP
#     # _transform = _transform.rotated(rotation_axis, deg_to_rad(random_angle))

#     # var rand_y_offset:float = randf_range(-7.5, 7.5)
#     # var offset_pos:Vector3 = _transform.basis.z * buffer_distance * mag + Vector3.UP * rand_y_offset

#     # new_rp.transform.origin += offset_pos

#     return new_rp


func getNode(node_id: int) -> OsmNodeRecord:
    if roads_data.node_by_id.has(node_id):
        return roads_data.node_by_id[node_id]
    else:
        push_warning("Node with ID %d not found in RoadsData." % node_id)
        return null
func getNodePosition(node_id: int) -> Vector3:
    var node = getNode(node_id)
    return node.position if node else Vector3.ZERO